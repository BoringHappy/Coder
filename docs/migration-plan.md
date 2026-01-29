# CodeMate Kubernetes Operator Migration Plan

## Overview

This document outlines the migration plan from the current Docker-based CodeMate setup to a Kubernetes operator with Python (Kopf) and FastAPI webhook server.

## Current Architecture

**Docker-based setup:**
- `start.sh` - Standalone script that manages Docker containers
- Container runs Claude Code with automated git/PR setup
- Cron-based PR monitoring inside container
- Manual container lifecycle management

**Key components:**
- `setup/docker/Dockerfile.codemate` - CodeMate pod image
- `setup/scripts/` - Shell scripts for git, GitHub, plugin setup
- `setup/scripts_python/setup-repo.py` - Repository cloning and PR management
- `plugins/` - Claude Code skills (git, PR management)

## Target Architecture

**Kubernetes operator:**
- Python-based operator using Kopf framework
- FastAPI webhook server for GitHub events
- Declarative CodeMate Custom Resources
- Automated pod lifecycle management
- Event-driven PR monitoring

## Simplified File Structure

We'll use a **minimal structure** to start, avoiding over-engineering:

```
codemate-operator/
├── operator.py                    # Single file: all Kopf handlers (~300 lines)
├── webhook.py                     # Single file: FastAPI + webhook handlers (~200 lines)
├── k8s_utils.py                   # Kubernetes helpers (~150 lines)
├── github_client.py               # GitHub API wrapper (~100 lines)
├── requirements.txt               # Python dependencies
├── Dockerfile.operator            # Operator image
├── Dockerfile.webhook             # Webhook image
├── config/
│   ├── operator.yaml              # All operator K8s resources
│   ├── webhook.yaml               # All webhook K8s resources
│   └── crd.yaml                   # CodeMate CRD definition
├── setup/                         # Existing setup (unchanged)
│   ├── docker/
│   │   ├── Dockerfile.codemate    # CodeMate pod image
│   │   └── Dockerfile.base
│   ├── scripts/                   # Shell scripts
│   └── scripts_python/            # Python setup scripts
└── plugins/                       # Claude Code plugins (unchanged)
```

**Total: 4 Python files, 3 YAML files, ~750 lines of new code**

## Migration Phases

### Phase 1: Foundation (Week 1)

**Goal:** Set up basic operator that can create CodeMate pods

**Tasks:**
1. Create `operator.py` with basic Kopf handlers
   - `@kopf.on.create` - Create pod when CodeMate CR is created
   - `@kopf.on.delete` - Cleanup pod when CR is deleted

2. Create `k8s_utils.py` with pod builder
   - Convert `start.sh` logic to Python
   - Build pod spec with proper env vars, volumes, secrets

3. Create `config/crd.yaml` - Define CodeMate Custom Resource
   ```yaml
   apiVersion: codemate.io/v1alpha1
   kind: CodeMate
   metadata:
     name: feature-auth
   spec:
     repository:
       url: https://github.com/org/repo.git
       branch: feature/auth
     github:
       tokenSecretRef:
         name: github-token
     anthropic:
       apiKeySecretRef:
         name: anthropic-key
   ```

4. Create `config/operator.yaml` - Operator deployment manifest

**Deliverable:** Can create CodeMate CR and see pod running Claude Code

**Testing:**
```bash
# Apply CRD
kubectl apply -f config/crd.yaml

# Create secrets
kubectl create secret generic github-token --from-literal=token=ghp_xxx
kubectl create secret generic anthropic-key --from-literal=token=sk-xxx

# Deploy operator
kubectl apply -f config/operator.yaml

# Create CodeMate instance
kubectl apply -f - <<EOF
apiVersion: codemate.io/v1alpha1
kind: CodeMate
metadata:
  name: test-feature
spec:
  repository:
    url: https://github.com/your-org/your-repo.git
    branch: test-feature
  github:
    tokenSecretRef:
      name: github-token
    user:
      name: "CodeMate Bot"
      email: "bot@example.com"
  anthropic:
    apiKeySecretRef:
      name: anthropic-key
EOF

# Verify pod is running
kubectl get pods
kubectl logs -f codemate-test-feature-xxx
```

### Phase 2: PR Monitoring (Week 2)

**Goal:** Migrate cron-based PR monitoring to operator timer

**Tasks:**
1. Add `@kopf.timer` handler to `operator.py`
   - Runs every 60 seconds
   - Checks all active CodeMate CRs

2. Create `github_client.py`
   - Wrap PyGithub for PR comment fetching
   - Handle authentication with GitHub token from secrets

3. Implement command injection in `k8s_utils.py`
   - Use Kubernetes exec API to send tmux commands
   - Migrate logic from `setup/scripts/monitor-pr.sh`

**Deliverable:** Operator automatically monitors PRs and injects comments into Claude sessions

**Testing:**
```bash
# Create CodeMate with PR
kubectl apply -f - <<EOF
apiVersion: codemate.io/v1alpha1
kind: CodeMate
metadata:
  name: pr-123
spec:
  repository:
    url: https://github.com/your-org/your-repo.git
    pullRequest: 123
  # ... rest of spec
EOF

# Add comment to PR #123 on GitHub
# Wait 60 seconds
# Check Claude session received the comment
kubectl exec -it codemate-pr-123-xxx -- tmux capture-pane -p
```

### Phase 3: Webhook Server (Week 3)

**Goal:** Real-time event handling via GitHub webhooks

**Tasks:**
1. Create `webhook.py` with FastAPI
   - `/webhook/github` endpoint
   - Signature verification
   - Event routing (issue_comment, pull_request_review)

2. Create `config/webhook.yaml`
   - Deployment, Service, Ingress
   - TLS certificate (cert-manager)

3. Implement webhook handlers
   - Find CodeMate CR for PR
   - Inject comment into Claude session
   - Add 👀 reaction to acknowledge

**Deliverable:** GitHub webhooks trigger immediate Claude responses

**Testing:**
```bash
# Deploy webhook server
kubectl apply -f config/webhook.yaml

# Get webhook URL
kubectl get ingress codemate-webhook

# Configure GitHub webhook
# Repository Settings > Webhooks > Add webhook
# URL: https://your-domain.com/webhook/github
# Content type: application/json
# Secret: <webhook-secret>
# Events: Issue comments, Pull request reviews

# Add comment to PR
# Verify immediate injection (no 60s delay)
```

### Phase 4: Production Hardening (Week 4)

**Goal:** Make operator production-ready

**Tasks:**
1. Add error handling and retries
2. Implement proper logging (structlog)
3. Add Prometheus metrics
4. Create Helm chart for easy deployment
5. Write documentation
6. Add health checks and readiness probes

**Deliverable:** Production-ready operator with monitoring and observability

## Key Design Decisions

### 1. Pod Lifecycle

**Decision:** Long-running pods (recommended)
- One pod per CodeMate CR
- Pod runs until CR is deleted or task completes
- Maintains Claude session state

**Alternative:** Job-based (future consideration)
- Create Kubernetes Job for each task
- Better resource utilization but loses session context

### 2. Webhook Architecture

**Decision:** Centralized webhook server
- Single webhook endpoint for all repos
- Routes events to appropriate CodeMate pods
- Runs as separate deployment from operator

**Benefits:**
- Single GitHub webhook to configure
- Easier to manage and monitor
- Can scale independently

### 3. State Management

**Decision:** CR status fields
- Store monitoring state in CodeMate CR status
- Last check time, processed comments, pod name
- No external database needed

**Example:**
```yaml
status:
  phase: Running
  podName: codemate-feature-auth-abc123
  pullRequestURL: https://github.com/org/repo/pull/123
  lastMonitorCheck: "2026-01-29T10:30:00Z"
  conditions:
    - type: PodReady
      status: "True"
    - type: GitHubAuthenticated
      status: "True"
```

### 4. Command Injection

**Decision:** Kubernetes exec API + tmux
- Use K8s exec to run commands in pod
- Send tmux commands to inject messages
- Same mechanism as current `monitor-pr.sh`

**Code example:**
```python
from kubernetes import client
from kubernetes.stream import stream

def inject_command(pod_name: str, namespace: str, message: str):
    """Inject message into Claude session via tmux"""
    api = client.CoreV1Api()

    exec_command = [
        'tmux', 'send-keys', '-t', 'claude-code',
        message, 'C-m'
    ]

    resp = stream(
        api.connect_get_namespaced_pod_exec,
        pod_name,
        namespace,
        command=exec_command,
        stderr=True,
        stdin=False,
        stdout=True,
        tty=False
    )

    return resp
```

### 5. Multi-Tenancy

**Decision:** Cluster-wide operator
- Operator watches all namespaces
- Users can create CodeMate CRs in any namespace
- RBAC controls who can create CRs

**Benefits:**
- Single operator deployment
- Flexible namespace organization
- Easier to manage

## Dependencies

### Python Packages

```txt
# Operator
kopf>=1.37.0                    # Kubernetes operator framework
kubernetes>=28.1.0              # Kubernetes Python client
PyGithub>=2.1.1                 # GitHub API client
pydantic>=2.5.0                 # Data validation
structlog>=24.1.0               # Structured logging

# Webhook
fastapi>=0.109.0                # Web framework
uvicorn[standard]>=0.27.0       # ASGI server
httpx>=0.26.0                   # Async HTTP client
```

### Kubernetes Components

- **cert-manager** - TLS certificate management for webhook
- **Ingress controller** - Expose webhook server (nginx/traefik)
- **Metrics server** - Resource monitoring (optional)
- **Prometheus** - Metrics collection (optional)

## Migration Checklist

### Pre-Migration
- [ ] Review current `start.sh` functionality
- [ ] Document all environment variables used
- [ ] List all GitHub permissions needed
- [ ] Identify all secrets (GitHub token, Anthropic key, Slack webhook)

### Phase 1: Foundation
- [ ] Create `operator.py` with basic handlers
- [ ] Create `k8s_utils.py` with pod builder
- [ ] Create `config/crd.yaml`
- [ ] Create `config/operator.yaml`
- [ ] Build and push operator image
- [ ] Test pod creation from CR

### Phase 2: PR Monitoring
- [ ] Add timer handler to `operator.py`
- [ ] Create `github_client.py`
- [ ] Implement command injection
- [ ] Test PR comment monitoring
- [ ] Verify 👀 reactions work

### Phase 3: Webhook Server
- [ ] Create `webhook.py` with FastAPI
- [ ] Implement signature verification
- [ ] Create `config/webhook.yaml`
- [ ] Deploy webhook server
- [ ] Configure GitHub webhooks
- [ ] Test real-time event handling

### Phase 4: Production
- [ ] Add error handling
- [ ] Implement structured logging
- [ ] Add Prometheus metrics
- [ ] Create Helm chart
- [ ] Write user documentation
- [ ] Add health checks
- [ ] Load testing
- [ ] Security review

### Post-Migration
- [ ] Update README with K8s instructions
- [ ] Archive `start.sh` (keep for reference)
- [ ] Update CI/CD pipelines
- [ ] Train team on new workflow
- [ ] Monitor production usage

## Rollback Plan

If migration encounters issues:

1. **Keep `start.sh` working** - Don't remove until operator is stable
2. **Parallel operation** - Run both Docker and K8s setups during transition
3. **Feature flags** - Use environment variables to toggle features
4. **Gradual rollout** - Migrate one team/repo at a time

## Success Metrics

- [ ] Operator can create/delete CodeMate pods
- [ ] PR monitoring works (60s polling)
- [ ] Webhook events trigger immediate responses
- [ ] No manual intervention needed for pod lifecycle
- [ ] Logs are structured and searchable
- [ ] Metrics available in Prometheus
- [ ] Documentation complete
- [ ] Team trained and comfortable with new workflow

## Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1: Foundation | Week 1 | Basic operator creates pods |
| Phase 2: PR Monitoring | Week 2 | Timer-based monitoring works |
| Phase 3: Webhook Server | Week 3 | Real-time event handling |
| Phase 4: Production | Week 4 | Production-ready operator |
| **Total** | **4 weeks** | **Full migration complete** |

## Next Steps

1. **Review this plan** - Discuss with team, adjust timeline
2. **Set up development cluster** - kind/minikube for local testing
3. **Create GitHub project** - Track tasks and progress
4. **Start Phase 1** - Begin with operator foundation
5. **Iterate** - Adjust plan based on learnings

## Questions to Resolve

Before starting implementation:

1. **Scale expectations** - How many concurrent CodeMate sessions?
2. **Resource limits** - CPU/memory per pod?
3. **Storage** - PersistentVolumes for Claude config?
4. **Networking** - Ingress controller preference?
5. **Monitoring** - Prometheus/Grafana setup?
6. **Secrets management** - External secrets operator?
7. **Multi-cluster** - Future requirement?

## References

- [Kopf Documentation](https://kopf.readthedocs.io/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Kubernetes Python Client](https://github.com/kubernetes-client/python)
- [GitHub Webhooks](https://docs.github.com/en/webhooks)
- [cert-manager](https://cert-manager.io/)
