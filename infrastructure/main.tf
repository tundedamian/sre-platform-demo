# Terraform configuration for SRE Platform Demo
# Main infrastructure file

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }

  # Using remote backend for state management
  backend "s3" {
    bucket = "sre-platform-terraform-state"
    key    = "sre-platform/terraform.tfstate"
    region = "us-west-2"
    
    # Enable state locking
    dynamodb_table = "terraform-locks"
  }
}

# Variables
variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "sre-platform-demo"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "sre-platform-cluster"
}

# Data sources
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
    load_config_file       = false
  }
}

# Kubernetes namespace for the application
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = "${var.environment}-app"
    labels = {
      environment = var.environment
      project     = var.project_name
      purpose     = "application"
    }
  }
}

# Kubernetes namespace for monitoring
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      environment = var.environment
      project     = var.project_name
      purpose     = "monitoring"
    }
  }
}

# Application deployment
resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = "sre-platform-app"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels = {
      app = "sre-platform-app"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "sre-platform-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "sre-platform-app"
        }
      }

      spec {
        container {
          name              = "app"
          image             = "ghcr.io/your-org/sre-platform-demo:latest"
          image_pull_policy = "Always"

          port {
            container_port = 3000
            name           = "http"
          }

          # Resource limits and requests
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          # Health checks
          liveness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        # Security context
        security_context {
          run_as_non_root = true
          run_as_user     = 1001
          fs_group        = 2000
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.app
  ]
}

# Application service
resource "kubernetes_service_v1" "app" {
  metadata {
    name      = "sre-platform-app-service"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_deployment_v1.app.spec[0].selector[0].match_labels[0].app
    }

    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }

    type = "ClusterIP"
  }

  depends_on = [
    kubernetes_deployment_v1.app
  ]
}

# Horizontal Pod Autoscaler
resource "kubernetes_horizontal_pod_autoscaler_v1" "app" {
  metadata {
    name      = "sre-platform-app-hpa"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.app.metadata[0].name
    }

    min_replicas = 3
    max_replicas = 10

    target_cpu_utilization_percentage = 70
  }

  depends_on = [
    kubernetes_deployment_v1.app
  ]
}

# Service account for the application
resource "kubernetes_service_account_v1" "app" {
  metadata {
    name      = "sre-platform-app-sa"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
}

# RBAC: Role for the application
resource "kubernetes_role_v1" "app" {
  metadata {
    name      = "sre-platform-app-role"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }
}

# RBAC: Role binding
resource "kubernetes_role_binding_v1" "app" {
  metadata {
    name      = "sre-platform-app-rolebinding"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.app.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.app.metadata[0].name
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
}

output "app_service_name" {
  value = kubernetes_service_v1.app.metadata[0].name
}

output "app_namespace" {
  value = kubernetes_namespace_v1.app.metadata[0].name
}

output "cluster_endpoint" {
  value     = data.aws_eks_cluster.cluster.endpoint
  sensitive = true
}