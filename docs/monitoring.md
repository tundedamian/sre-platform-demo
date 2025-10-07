# Monitoring Setup

This document details the implementation of the comprehensive monitoring stack for the SRE Platform Demo, following industry best practices and the Four Golden Signals.

## Monitoring Stack Components

### Prometheus
- **Purpose**: Metrics collection and storage
- **Features**: Multi-dimensional data model, PromQL query language, service discovery
- **Configuration**: Managed through Kubernetes ConfigMaps

### Grafana
- **Purpose**: Visualization and dashboard creation
- **Features**: Rich visualization options, alerting, dashboard sharing
- **Integration**: Connected to Prometheus as primary data source

### AlertManager
- **Purpose**: Alert routing and notification management
- **Features**: Deduplication, grouping, inhibition, notification channels
- **Configuration**: Defined through alertmanager.yml

### Node Exporter
- **Purpose**: System-level metrics collection
- **Features**: CPU, memory, disk, network metrics
- **Deployment**: Running as DaemonSet on all nodes

## Metrics Collection

### Four Golden Signals

#### 1. Latency
- **Quantile-based latency**: p50, p95, p99 response times
- **API endpoint latency**: By endpoint and HTTP method
- **Database query latency**: Slow query tracking

```promql
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, handler))
```

#### 2. Traffic
- **Request rate**: Requests per second by endpoint
- **Throughput**: Data transfer rates
- **Active connections**: Concurrent connection tracking

```promql
sum(rate(http_requests_total[5m])) by (code, handler)
```

#### 3. Errors
- **Error rate**: Percentage of failed requests
- **Error breakdown**: By error type and endpoint
- **System errors**: Infrastructure-level failures

```promql
sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
```

#### 4. Saturation
- **Resource utilization**: CPU, memory, disk usage
- **Queue lengths**: Task queue lengths
- **Connection pool**: Database connection usage

```promql
1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))
```

### System Metrics

#### Infrastructure Metrics
- Node CPU, memory, disk, and network utilization
- Kubernetes cluster metrics (pods, nodes, resource usage)
- Container metrics (CPU, memory, restarts)

#### Application Metrics
- Custom business metrics
- Database connection pool metrics
- Cache hit/miss ratios
- Queue processing rates

## Dashboard Configuration

### Infrastructure Overview Dashboard
- Node resource utilization (CPU, memory, disk, network)
- Kubernetes cluster health (pods, deployments, services)
- System load and availability

### Application Performance Dashboard
- Application response times and throughput
- Error rates and breakdowns
- Business transaction metrics

### SLI/SLO Dashboard
- Service level indicator tracking
- Error budget consumption
- Availability percentage over time

### Database Metrics Dashboard
- Query performance metrics
- Connection pool utilization
- Database health indicators

### Network Metrics Dashboard
- Bandwidth utilization
- Latency between services
- Network error rates

## Alerting Configuration

### Critical Alerts
- **High Error Rate**: Error rate > 10% for 5 minutes
- **High Latency**: 95th percentile response time > 1 second for 5 minutes
- **Service Down**: Service unavailable for more than 2 minutes
- **High Saturation**: CPU/Memory > 90% for more than 10 minutes

### Warning Alerts
- **Moderate Error Rate**: Error rate > 5% for 10 minutes
- **Increasing Latency**: 95th percentile response time > 500ms for 10 minutes
- **Resource Pressure**: CPU/Memory > 80% for more than 15 minutes
- **Disk Space Low**: Disk usage > 85% for more than 10 minutes

### Alert Routing
- **Critical Alerts**: Immediate notification via PagerDuty/Slack
- **Warning Alerts**: Notification in designated Slack channels
- **Info Alerts**: Logged for review during business hours

### Example Alert Rules

```yaml
groups:
- name: application
  rules:
  - alert: HighErrorRate
    expr: sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) > 0.05
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is above 5% for more than 5 minutes"

  - alert: HighLatency
    expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, handler)) > 1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High latency detected"
      description: "95th percentile response time is above 1 second"
```

## Service Level Indicators (SLIs) and Objectives (SLOs)

### SLI Definitions
- **Availability**: Percentage of time service is operational
- **Latency**: Percentage of requests served within time threshold
- **Quality**: Percentage of requests that are successful

### SLO Examples
- **Availability SLO**: 99.9% uptime over 30-day period
- **Latency SLO**: 95% of requests served within 500ms
- **Quality SLO**: 99.5% of requests result in success

### Error Budget
- Calculated as: 100% - SLO target
- Used to govern deployment and experimentation pace
- When budget is consumed, new feature development pauses

## Implementation Steps

### 1. Deploy Prometheus Operator
```bash
kubectl apply -f monitoring/prometheus-operator/
```

### 2. Configure Service Monitors
```bash
kubectl apply -f monitoring/service-monitors/
```

### 3. Deploy Grafana
```bash
kubectl apply -f monitoring/grafana/
```

### 4. Configure Data Sources
```bash
kubectl apply -f monitoring/grafana/datasources/
```

### 5. Import Dashboards
```bash
kubectl apply -f monitoring/grafana/dashboards/
```

### 6. Deploy AlertManager
```bash
kubectl apply -f monitoring/alertmanager/
```

### 7. Configure Alert Rules
```bash
kubectl apply -f monitoring/prometheus/rules/
```

## Integration with Application

### Instrumentation
- Applications expose metrics at `/metrics` endpoint
- Prometheus scrapes metrics at configured intervals
- Custom application metrics using Prometheus client libraries

### Example Application Metrics
```python
from prometheus_client import Counter, Histogram, Gauge

# Request counter
REQUEST_COUNT = Counter('app_requests_total', 'Total requests', ['method', 'endpoint'])

# Request duration histogram
REQUEST_LATENCY = Histogram('app_request_duration_seconds', 'Request latency', ['endpoint'])

# Active connections gauge
ACTIVE_CONNECTIONS = Gauge('app_active_connections', 'Active database connections')
```

## Monitoring Best Practices

### Metric Best Practices
- Use consistent naming conventions
- Apply appropriate labels for dimensionality
- Choose appropriate metric types (counter, gauge, histogram)
- Set appropriate retention policies

### Alerting Best Practices
- Keep alerts actionable
- Avoid alert noise through proper grouping
- Use appropriate thresholds based on SLOs
- Include clear documentation in alert annotations

### Dashboard Best Practices
- Organize dashboards by team/service
- Use appropriate time ranges
- Include drill-down capabilities
- Ensure dashboards are mobile-friendly

## Validation and Testing

### Monitoring Tests
- Verify all metrics are being collected
- Test alert rules in staging environment
- Validate dashboard data accuracy
- Confirm alert notifications work correctly

### Load Testing Integration
- Run load tests with monitoring enabled
- Verify scaling behavior under load
- Validate that alerts trigger appropriately during stress
- Document performance baselines