# Runbook: Application Performance Degradation

## Overview
This runbook addresses performance degradation in the SRE Platform Demo application, providing step-by-step instructions for identification, diagnosis, and resolution.

## Alert Description
- **Symptom**: Application response times exceeding SLO (p95 latency > 500ms for more than 5 minutes)
- **Priority**: P1 - High
- **SLA**: Respond within 15 minutes
- **Primary On-Call**: SRE Team
- **Secondary On-Call**: Development Team

## Initial Diagnosis

### 1. Verify the Alert
```bash
# Check current application latency
kubectl exec -it -n monitoring prometheus-server-xxxxx -- /bin/bash
# Run PromQL query
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, handler))
```

### 2. Check Service Health
```bash
# Verify application pods status
kubectl get pods -n production
kubectl describe deployment/sre-platform-app -n production

# Check resource utilization
kubectl top pods -n production
kubectl top nodes
```

### 3. Validate Infrastructure
```bash
# Check cluster health
kubectl get nodes
kubectl get componentstatuses

# Check resource quotas and limits
kubectl describe resourcequota -n production
```

## Detailed Diagnosis

### 1. Analyze Traffic Patterns
- Check if there's an increase in traffic causing the performance issue
- Review load balancer logs for traffic spikes
- Check if the issue is isolated to specific endpoints or affects the entire application

### 2. Check Database Performance
```bash
# Check database connection pool
kubectl exec -it -n production db-pod-xxxxx -- psql -c "SELECT count(*) FROM pg_stat_activity;"

# Look for slow queries
kubectl logs -n production db-pod-xxxxx | grep "slow query"
```

### 3. Examine Application Logs
```bash
# Check application logs for errors
kubectl logs -n production -l app=sre-platform-app --tail=100 | grep -i error

# Look for specific error patterns
kubectl logs -n production -l app=sre-platform-app | grep -E "(timeout|exception|error)"
```

### 4. Review Resource Utilization
```bash
# Check CPU and memory limits
kubectl describe -n production -l app=sre-platform-app

# Check if there are resource contention issues
kubectl get events -n production
```

## Resolution Steps

### Immediate Actions

#### 1. Scale Application Resources
```bash
# Increase replica count temporarily
kubectl scale deployment/sre-platform-app -n production --replicas=6

# Increase resource limits if needed
kubectl patch deployment/sre-platform-app -n production -p '{"spec":{"template":{"spec":{"containers":[{"name":"app","resources":{"requests":{"cpu":"500m","memory":"1Gi"},"limits":{"cpu":"1","memory":"2Gi"}}}]}}}}'
```

#### 2. Restart Problematic Components
```bash
# If specific pods are problematic, restart them
kubectl delete pod <problematic-pod-name> -n production
```

#### 3. Check for Bad Deployments
```bash
# Check rollout history
kubectl rollout history deployment/sre-platform-app -n production

# If recent deployment caused issues, rollback
kubectl rollout undo deployment/sre-platform-app -n production
```

### Medium-term Actions

#### 1. Optimize Database Queries
- Identify slow queries from database logs
- Add appropriate indexes
- Optimize application queries

#### 2. Resource Tuning
- Analyze CPU/memory usage patterns
- Adjust resource requests and limits appropriately
- Consider implementing horizontal pod autoscaling

#### 3. Circuit Breakers
- Implement circuit breakers for external dependencies
- Add timeout configurations to prevent resource exhaustion

## Monitoring and Validation

### 1. Verify Resolution
```bash
# Monitor latency after applying fixes
kubectl exec -it -n monitoring prometheus-server-xxxxx -- /bin/bash
# Run latency query again
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, handler))
```

### 2. Confirm Service Recovery
- Verify that the alert has cleared
- Confirm that the application is serving requests within SLOs
- Check that all system components are healthy

### 3. Capacity Validation
```bash
# Check that scaling has returned to normal levels
kubectl get hpa -n production
kubectl get pods -n production
```

## Communication

### 1. Internal Communication
- Update incident status in tracking system
- Notify stakeholders of resolution
- Document incident in knowledge base

### 2. External Communication (if needed)
- If customer impact occurred, prepare status update
- Communicate resolution to customers if service was affected

## Post-Incident Actions

### 1. Incidents Review
- Conduct post-incident review meeting
- Identify root cause using the 5 Whys technique
- Document lessons learned

### 2. Preventive Measures
- Implement fixes to prevent recurrence
- Update monitoring and alerting if needed
- Add or improve automated tests

### 3. Process Improvements
- Update runbook based on lessons learned
- Add monitoring for indicators that could provide earlier warning
- Review SLO targets if they were unrealistic

## Additional Resources
- [Monitoring Dashboard](http://grafana.example.com/dashboards)
- [Application Logs](http://loki.example.com/)
- [Infrastructure Metrics](http://prometheus.example.com/)
- [Kubernetes Cluster Status](http://kubernetes.example.com/)
- [Database Metrics](http://db-monitoring.example.com/)

## Emergency Contacts
- Primary On-Call: [SRE PagerDuty]
- Secondary On-Call: [Dev Team Slack]
- Manager: [Contact Information]
- Infrastructure Team: [Team Contact]