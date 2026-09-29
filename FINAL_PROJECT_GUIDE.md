# PulseGuard - Final Project Demonstration Guide

**Complete Step-by-Step Guide for Windows PowerShell**

**All commands are PowerShell-compatible (Windows 10/11)**

---

## 📋 Quick Demo (15 minutes)

### Setup (1 minute)

```powershell
# Navigate to project
cd $env:USERPROFILE\Desktop\PulseGuard

# Verify all components
.\scripts\verify-all-phases.ps1
```

**Expected**: All 8 checks pass ✅

---

## 🔍 Detailed Demo (45 minutes)

### Part 1: Application & Testing (5 minutes)

#### 1.1 Run Flask Tests

```powershell
# Set Python path
$env:PYTHONPATH = "$PWD/app;$env:PYTHONPATH"

# Run all tests
python -m pytest tests/ -v

# Should show: 26 passed
```

#### 1.2 Test Application Locally

```powershell
# Start application
python app/app.py

# In another PowerShell window:
Start-Sleep -Seconds 2

# Test endpoints
Invoke-WebRequest -Uri http://localhost:5000/health -UseBasicParsing
Invoke-WebRequest -Uri http://localhost:5000/version -UseBasicParsing
Invoke-WebRequest -Uri http://localhost:5000/metrics -UseBasicParsing

# Stop application (Ctrl+C in original window)
```

---

### Part 2: Docker (5 minutes)

#### 2.1 Build Docker Image

```powershell
# Build image
docker build -t pulseguard:1.0.0 -t pulseguard:latest .

# Verify build
docker images | Select-String pulseguard
```

#### 2.2 Run Docker Container

```powershell
# Run container
docker run -d --name pulseguard-demo `
  -p 5000:5000 `
  -e ENVIRONMENT=production `
  pulseguard:latest

# Wait for startup
Start-Sleep -Seconds 3

# Test container
Invoke-WebRequest -Uri http://localhost:5000/health -UseBasicParsing
Invoke-WebRequest -Uri http://localhost:5000/metrics -UseBasicParsing

# View logs
docker logs pulseguard-demo

# Cleanup
docker stop pulseguard-demo
docker rm pulseguard-demo
```

---

### Part 3: Kubernetes Deployment (15 minutes)

#### 3.1 Verify Kubernetes is Running

```powershell
# Check cluster
kubectl cluster-info

# Check nodes
kubectl get nodes
```

#### 3.2 Deploy All Components

```powershell
# Deploy namespace
kubectl apply -f k8s/namespace.yaml

# Deploy PulseGuard
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Wait for pods
Start-Sleep -Seconds 15

# Check pods
kubectl get pods -n pulseguard

# Should show: 2 pulseguard pods Running
```

#### 3.3 Deploy Prometheus

```powershell
# Deploy Prometheus
kubectl apply -f k8s/prometheus-configmap.yaml
kubectl apply -f k8s/prometheus-deployment.yaml

# Wait for pod
Start-Sleep -Seconds 10

# Check pod
kubectl get pods -n pulseguard -l app=prometheus
```

#### 3.4 Deploy Grafana

```powershell
# Deploy Grafana
kubectl apply -f k8s/grafana-configmap.yaml
kubectl apply -f k8s/grafana-deployment.yaml

# Wait for pod
Start-Sleep -Seconds 10

# Check pod
kubectl get pods -n pulseguard -l app=grafana
```

#### 3.5 Verify All Pods Running

```powershell
# Get all pods
kubectl get pods -n pulseguard

# Should show:
# - 2 pulseguard pods (Running 1/1)
# - 1 prometheus pod (Running 1/1)
# - 1 grafana pod (Running 1/1)
```

---

### Part 4: Testing PulseGuard (5 minutes)

#### 4.1 Access Application

```powershell
# Port forward
$job = Start-Job -ScriptBlock { kubectl port-forward -n pulseguard service/pulseguard-service 8086:80 }

Start-Sleep -Seconds 5

# Test endpoints
Invoke-WebRequest -Uri http://localhost:8086/health -UseBasicParsing
Invoke-WebRequest -Uri http://localhost:8086/metrics -UseBasicParsing

# Stop port forward
Stop-Job $job
Remove-Job $job -Force
```

---

### Part 5: Prometheus Monitoring (5 minutes)

#### 5.1 Access Prometheus Web UI

```powershell
# Port forward
$job = Start-Job -ScriptBlock { kubectl port-forward -n pulseguard service/prometheus-service 9090:9090 }

# In browser: http://localhost:9090
# Look at:
# - Targets tab (should show pulseguard UP)
# - Graph tab (query: pulseguard_request_count_total)
# - Alerts tab (should show 8 alert rules)

# Stop port forward
Stop-Job $job
Remove-Job $job -Force
```

#### 5.2 Verify Alert Rules Programmatically

```powershell
$podName = kubectl get pods -n pulseguard -l app=prometheus -o jsonpath='{.items[0].metadata.name}'

$rulesJson = kubectl exec -n pulseguard $podName -- wget -q -O- http://localhost:9090/api/v1/rules | ConvertFrom-Json

Write-Host "Alert Rules Loaded: $($rulesJson.data.groups[0].rules.Count)"
foreach ($rule in $rulesJson.data.groups[0].rules) {
    Write-Host "  - $($rule.name)"
}
```

**Expected**: 8 alert rules loaded

---

### Part 6: Grafana Dashboards (5 minutes)

#### 6.1 Access Grafana

```powershell
# Port forward
$job = Start-Job -ScriptBlock { kubectl port-forward -n pulseguard service/grafana-service 3000:3000 }

# In browser: http://localhost:3000
# Login: admin / admin
# Navigate to: Dashboards → PulseGuard → PulseGuard Application Monitoring
# View: Request rate, CPU, memory, health status, etc.

# Stop port forward
Stop-Job $job
Remove-Job $job -Force
```

---

### Part 7: Self-Healing Demo (5 minutes)

#### 7.1 Automated Test

```powershell
# Run self-healing test
.\scripts\test-self-healing.ps1

# Watch as:
# 1. Initial state: 2 pods running
# 2. Pod deleted (simulated failure)
# 3. Kubernetes auto-creates new pod
# 4. Final state: 2 pods running again
# 5. Recovery time: < 5 seconds

# Expected: SUCCESS - SELF-HEALING VERIFIED
```

#### 7.2 Manual Demonstration

```powershell
# Terminal 1: Watch pods
kubectl get pods -n pulseguard -l app=pulseguard -w

# Terminal 2: Delete a pod
$podName = kubectl get pods -n pulseguard -l app=pulseguard -o jsonpath='{.items[0].metadata.name}'
kubectl delete pod $podName -n pulseguard

# Watch Terminal 1: New pod appears immediately!
```

---

## 🔄 Complete Verification

### Run All Verification Scripts

```powershell
# 1. Comprehensive verification
.\scripts\verify-all-phases.ps1

# 2. Self-healing test
.\scripts\test-self-healing.ps1

# 3. Check Prometheus alert rules
$podName = kubectl get pods -n pulseguard -l app=prometheus -o jsonpath='{.items[0].metadata.name}'
$rulesJson = kubectl exec -n pulseguard $podName -- wget -q -O- http://localhost:9090/api/v1/rules | ConvertFrom-Json
Write-Host "Prometheus Rules: $($rulesJson.data.groups[0].rules.Count) loaded"

# 4. Check Prometheus targets
$targetsJson = kubectl exec -n pulseguard $podName -- wget -q -O- http://localhost:9090/api/v1/targets | ConvertFrom-Json
foreach ($target in $targetsJson.data.activeTargets) {
    Write-Host "$($target.labels.job): $($target.health)"
}
```

---

## 📊 Key Demonstration Points

### What to Highlight

1. **Application Layer**
   - 26 passing tests (reliability)
   - Health check endpoint (monitoring)
   - Metrics endpoint (observability)

2. **Container Layer**
   - Multi-stage Docker build (efficiency)
   - Production-ready with Gunicorn
   - Portable across environments

3. **Orchestration**
   - 2-replica deployment (redundancy)
   - Zero-downtime rolling updates
   - Automatic scheduling

4. **Self-Healing**
   - Pod auto-recovery < 5 seconds
   - No manual intervention
   - Health checks working

5. **Monitoring**
   - Prometheus collecting metrics
   - 8 alert rules configured
   - Real-time Grafana dashboards

6. **Automation**
   - Jenkins CI/CD pipeline
   - Automated tests before deploy
   - One-command deployment

---

## 🎯 Presentation Flow

**Total Time: ~45 minutes**

### Slide 1: Problem (2 min)
- Manual deployments are slow, unreliable, opaque
- Need automation, monitoring, self-healing

### Slide 2: Solution - PulseGuard (3 min)
- 7-phase complete DevOps platform
- All running on local Kubernetes

### Slide 3: Architecture Overview (3 min)
- Show diagram: App → Docker → K8s → Prometheus → Grafana
- Data flow and dependencies

### Slide 4: Demo - Local Testing (5 min)
- Run tests: `python -m pytest tests/ -v` (26 passed)
- Show test output

### Slide 5: Demo - Docker (5 min)
- Build image: `docker build ...`
- Run container: `docker run ...`
- Test endpoints

### Slide 6: Demo - Kubernetes Deployment (10 min)
- Deploy components: `kubectl apply -f ...`
- Show pods running
- Port forward and test

### Slide 7: Demo - Monitoring (8 min)
- Open Prometheus: http://localhost:9090
- Show targets (both UP)
- Show alert rules (8 configured)
- Open Grafana: http://localhost:3000
- Show dashboard with live metrics

### Slide 8: Demo - Self-Healing (5 min)
- Run test: `.\scripts\test-self-healing.ps1`
- Show pod being deleted
- Show new pod auto-created
- Show recovery time < 5 seconds

### Slide 9: Conclusion (2 min)
- Complete DevOps workflow
- Production-ready practices
- Ready for real-world deployment

---

## 🛑 Cleanup

### Remove All Deployments

```powershell
# Delete entire namespace (removes all pods)
kubectl delete namespace pulseguard

# Verify deletion
kubectl get pods -n pulseguard
```

### Remove Docker Container (if running)

```powershell
docker stop pulseguard-demo
docker rm pulseguard-demo
```

### Stop Port Forwards

```powershell
# In PowerShell where port-forward is running: Ctrl+C
```

---

## 📌 Troubleshooting During Demo

### Pod Not Running?
```powershell
kubectl describe pod -n pulseguard <pod-name>
kubectl logs -n pulseguard <pod-name>
```

### Can't Access Application?
```powershell
# Verify port-forward is running
kubectl port-forward -n pulseguard service/pulseguard-service 8086:80

# Test from another window
Invoke-WebRequest -Uri http://localhost:8086/health -UseBasicParsing
```

### Prometheus Targets Down?
```powershell
# Check if PulseGuard is responding
kubectl port-forward -n pulseguard service/pulseguard-service 8086:80
Invoke-WebRequest -Uri http://localhost:8086/metrics -UseBasicParsing

# Check Prometheus logs
kubectl logs -n pulseguard -l app=prometheus
```

### Grafana Shows No Data?
```powershell
# Wait 15-30 seconds for first scrape
Start-Sleep -Seconds 30

# Check Prometheus has data
# Visit: http://localhost:9090/graph
# Query: pulseguard_request_count_total

# Refresh Grafana dashboard
```

---

## ✅ Pre-Demo Checklist

- [ ] Docker Desktop running with Kubernetes enabled
- [ ] All pods deployed and running
- [ ] Python dependencies installed
- [ ] kubectl configured and working
- [ ] All scripts have execute permissions
- [ ] Network connectivity verified
- [ ] Port 5000, 8080, 8086, 9090, 3000 available
- [ ] Prometheus alert rules verified (8 loaded)
- [ ] Grafana dashboard accessible
- [ ] Self-healing test passes

---

## 📚 Additional Resources

- **README.md** - Complete project overview
- **docs/ARCHITECTURE.md** - System architecture
- **docs/SETUP.md** - Detailed setup
- **docs/PROMETHEUS.md** - Prometheus guide
- **docs/GRAFANA.md** - Grafana guide
- **docs/JENKINS.md** - Jenkins guide
- **docs/PHASE7_COMPLETION.md** - Self-healing report

---

**Last Updated**: September 27, 2026  
**Status**: ✅ Ready for Production Demo
