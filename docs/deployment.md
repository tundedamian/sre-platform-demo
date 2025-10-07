# Deployment Guide

This guide provides step-by-step instructions for deploying the SRE Platform Demo to a cloud environment.

## Prerequisites

- **Cloud Provider Account**: AWS, GCP, or Azure with appropriate permissions
- **Terraform**: v1.0+ installed locally
- **kubectl**: Kubernetes command-line tool
- **Docker**: For building container images
- **GitHub Account**: For CI/CD pipeline setup

## Environment Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/sre-platform-demo.git
cd sre-platform-demo
```

### 2. Set Up Cloud Provider Credentials

#### AWS
```bash
# Configure AWS CLI
aws configure
```

#### GCP
```bash
# Authenticate with Google Cloud
gcloud auth application-default login
```

#### Azure
```bash
# Login to Azure
az login
```

### 3. Initialize Terraform

```bash
cd infrastructure
terraform init
```

## Infrastructure Deployment

### 1. Configure Variables

Create a `terraform.tfvars` file with your specific configuration:

```hcl
project_name = "sre-platform-demo"
region       = "us-west-2"  # Adjust for your preferred region
environment  = "dev"
```

### 2. Review Infrastructure Plan

```bash
terraform plan
```

### 3. Deploy Infrastructure

```bash
terraform apply
```

### 4. Configure kubectl Context

After infrastructure deployment, configure kubectl to connect to your cluster:

```bash
# For AWS EKS
aws eks --region <region> update-kubeconfig --name <cluster-name>

# For GCP GKE
gcloud container clusters get-credentials <cluster-name> --zone <zone> --project <project-id>

# For Azure AKS
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
```

## Application Deployment

### 1. Build Application Container

```bash
# Navigate to application directory
cd ../application

# Build and tag container image
docker build -t sre-platform-app:latest .

# Tag for your container registry
docker tag sre-platform-app:latest <your-registry>/sre-platform-app:latest
```

### 2. Push Container to Registry

```bash
# Login to container registry
docker login <your-registry>

# Push image
docker push <your-registry>/sre-platform-app:latest
```

### 3. Deploy to Kubernetes

```bash
# Navigate back to infrastructure directory
cd ../infrastructure

# Apply Kubernetes manifests
kubectl apply -f k8s-manifests/
```

## Monitoring Stack Deployment

### 1. Deploy Prometheus and Grafana

```bash
# Install Prometheus Operator
kubectl apply -f monitoring/prometheus-operator/

# Install Grafana
kubectl apply -f monitoring/grafana/

# Install Prometheus
kubectl apply -f monitoring/prometheus/

# Install AlertManager
kubectl apply -f monitoring/alertmanager/
```

### 2. Configure Service Monitors

```bash
kubectl apply -f monitoring/service-monitors/
```

### 3. Import Grafana Dashboards

1. Access Grafana (typically on port 3000)
2. Import dashboards from `monitoring/dashboards/`
3. Configure data sources to connect to Prometheus

## CI/CD Pipeline Setup

### 1. GitHub Actions Configuration

The repository includes GitHub Actions workflows in `.github/workflows/`:

- `ci.yml`: Runs tests and builds container images
- `cd.yml`: Deploys to Kubernetes cluster (requires secrets)
- `security-scan.yml`: Performs security scanning

### 2. Required GitHub Secrets

Add these secrets to your GitHub repository:

```
AWS_ACCESS_KEY_ID: [Your AWS Access Key]
AWS_SECRET_ACCESS_KEY: [Your AWS Secret Key]
DOCKER_USERNAME: [Your Docker Hub Username]
DOCKER_PASSWORD: [Your Docker Hub Password]
KUBE_CONFIG_DATA: [Base64 encoded kubeconfig file]
```

## Configuration Management

### 1. Environment Variables

Application configuration is managed through Kubernetes ConfigMaps and Secrets:

```bash
# Create ConfigMap for application settings
kubectl create configmap app-config \
  --from-literal=DATABASE_URL=postgresql://localhost:5432/app \
  --from-literal=LOG_LEVEL=info

# Create Secret for sensitive data
kubectl create secret generic app-secrets \
  --from-literal=DB_PASSWORD=your-password \
  --from-literal=API_KEY=your-api-key
```

### 2. Feature Flags

Feature flags are managed through a configuration service:

```bash
kubectl apply -f configs/feature-flags.yaml
```

## Health Checks and Verification

### 1. Verify Application Deployment

```bash
# Check pods status
kubectl get pods

# Check services
kubectl get svc

# Check ingress
kubectl get ingress
```

### 2. Verify Monitoring Stack

```bash
# Check monitoring pods
kubectl get pods -n monitoring

# Port-forward to access Grafana
kubectl port-forward -n monitoring service/grafana 3000:80
```

### 3. Test Application Endpoints

```bash
# Get application URL
kubectl get ingress

# Test health endpoint
curl http://<ingress-url>/health

# Test metrics endpoint
curl http://<ingress-url>/metrics
```

## Post-Deployment Steps

### 1. Set Up Alerts

Configure alerting rules in AlertManager:

```bash
kubectl apply -f monitoring/alertmanager/alerts/
```

### 2. Configure SLOs

Set up SLO tracking:

```bash
kubectl apply -f monitoring/slo/
```

### 3. Run Load Tests

Execute load testing to validate system capacity:

```bash
# Run load test script
./scripts/load-test.sh
```

## Rollback Procedures

### 1. Manual Rollback

If issues occur, rollback to previous version:

```bash
kubectl rollout undo deployment/sre-platform-app
```

### 2. Automated Rollback

The CI/CD pipeline includes automated rollback based on health checks and metrics.

## Troubleshooting

### Common Issues

1. **Failed Pod Deployments**: Check logs with `kubectl logs <pod-name>`
2. **Service Unavailable**: Verify ingress and service configurations
3. **Monitoring Not Working**: Check Prometheus targets and service monitors
4. **CI/CD Failures**: Verify GitHub secrets and permissions

### Useful Commands

```bash
# View cluster status
kubectl get nodes

# Check resource usage
kubectl top nodes
kubectl top pods

# View events
kubectl get events --sort-by=.metadata.creationTimestamp

# Get detailed pod information
kubectl describe pod <pod-name>
```

## Cleanup

To remove the deployment:

```bash
# Delete Kubernetes resources
kubectl delete -f k8s-manifests/
kubectl delete -f monitoring/

# Remove infrastructure
cd infrastructure
terraform destroy
```

This deployment guide provides a complete workflow for setting up the SRE Platform Demo in your environment.