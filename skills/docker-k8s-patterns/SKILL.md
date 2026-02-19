# Docker & Kubernetes Patterns

## Dockerfile Best Practices

### Multi-Stage Builds
```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS production
WORKDIR /app
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
USER nodejs
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Minimal Base Images
- Use `-alpine` variants when possible
- Use `-slim` for Debian-based when Alpine isn't compatible
- Avoid `latest` tag - pin specific versions
- Consider distroless images for production

### .dockerignore
```
node_modules
npm-debug.log
.git
.gitignore
.env*
*.md
.nyc_output
coverage
.docker
Dockerfile*
docker-compose*
.idea
.vscode
```

### Layer Optimization
- Order instructions from least to most frequently changing
- Combine RUN commands with `&&` to reduce layers
- Clean up in the same layer: `RUN apt-get update && apt-get install -y pkg && rm -rf /var/lib/apt/lists/*`
- Use `COPY` instead of `ADD` unless extracting archives

---

## Docker Compose for Local Development

### Basic Service Pattern
```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: development
    volumes:
      - .:/app
      - /app/node_modules
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgres://user:pass@db:5432/mydb
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-network

  db:
    image: postgres:15-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: mydb
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - app-network

volumes:
  postgres_data:

networks:
  app-network:
    driver: bridge
```

### Development Overrides
```yaml
# docker-compose.override.yml (auto-loaded)
services:
  app:
    command: npm run dev
    environment:
      - DEBUG=app:*
```

---

## Kubernetes Deployment Patterns

### Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: production
  labels:
    app: my-app
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: my-app
        version: v1
    spec:
      containers:
        - name: my-app
          image: my-registry/my-app:1.2.3
          ports:
            - containerPort: 3000
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "500m"
          env:
            - name: NODE_ENV
              value: "production"
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: my-app-secrets
                  key: database-url
          livenessProbe:
            httpGet:
              path: /health/live
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          startupProbe:
            httpGet:
              path: /health/live
              port: 3000
            failureThreshold: 30
            periodSeconds: 10
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
```

### Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: production
spec:
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 3000
  type: ClusterIP
```

### Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - api.example.com
      secretName: my-app-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

---

## ConfigMaps and Secrets

### ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-config
  namespace: production
data:
  LOG_LEVEL: "info"
  API_TIMEOUT: "30000"
  config.json: |
    {
      "feature_flags": {
        "new_ui": true
      }
    }
```

### Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secrets
  namespace: production
type: Opaque
stringData:
  database-url: "postgres://user:password@host:5432/db"
  api-key: "secret-api-key"
```

### Using in Deployment
```yaml
env:
  - name: LOG_LEVEL
    valueFrom:
      configMapKeyRef:
        name: my-app-config
        key: LOG_LEVEL
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: my-app-secrets
        key: database-url
volumes:
  - name: config-volume
    configMap:
      name: my-app-config
volumeMounts:
  - name: config-volume
    mountPath: /app/config
    readOnly: true
```

---

## Probes

### Probe Types
| Probe | Purpose | Failure Behavior |
|-------|---------|------------------|
| **Startup** | Wait for app initialization | Container killed, restarts |
| **Liveness** | Detect deadlocks/hangs | Container killed, restarts |
| **Readiness** | Check if ready for traffic | Removed from Service endpoints |

### Probe Methods
```yaml
# HTTP GET
httpGet:
  path: /health
  port: 3000
  httpHeaders:
    - name: X-Custom-Header
      value: probe

# TCP Socket
tcpSocket:
  port: 3000

# Exec command
exec:
  command:
    - /bin/sh
    - -c
    - "curl -f http://localhost:3000/health"
```

---

## Resource Management

### Resource Requests and Limits
```yaml
resources:
  requests:    # Scheduling guarantee
    memory: "128Mi"
    cpu: "100m"      # 100 millicores = 0.1 CPU
  limits:      # Hard cap
    memory: "256Mi"
    cpu: "500m"
```

### Guidelines
- **Requests**: Set based on normal operation metrics
- **Limits**: Set 2x requests for memory, allow CPU burst
- **Memory**: Hard limit - OOMKilled if exceeded
- **CPU**: Soft limit - throttled, not killed

---

## Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
```

---

## Namespace Organization

```
namespaces/
├── production/     # Live traffic
├── staging/        # Pre-prod testing
├── development/    # Development environment
└── monitoring/     # Prometheus, Grafana
```

### Namespace Resource Quotas
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resource-quota
  namespace: development
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
```

---

## Helm Chart Structure

```
my-app/
├── Chart.yaml          # Chart metadata
├── values.yaml         # Default values
├── values-prod.yaml    # Production overrides
├── templates/
│   ├── _helpers.tpl    # Template helpers
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   └── hpa.yaml
└── charts/             # Dependencies
```

### Chart.yaml
```yaml
apiVersion: v2
name: my-app
description: My Application Helm chart
type: application
version: 1.0.0
appVersion: "1.2.3"
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

### values.yaml
```yaml
replicaCount: 2

image:
  repository: my-registry/my-app
  tag: "1.2.3"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  host: api.example.com

resources:
  requests:
    memory: 128Mi
    cpu: 100m
  limits:
    memory: 256Mi
    cpu: 500m

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilization: 70
```

---

## Common Commands

```bash
# Docker
docker build -t my-app:latest .
docker-compose up -d
docker-compose logs -f app

# Kubernetes
kubectl apply -f deployment.yaml
kubectl get pods -n production
kubectl logs -f deployment/my-app -n production
kubectl describe pod my-app-xxx -n production
kubectl rollout status deployment/my-app -n production
kubectl rollout undo deployment/my-app -n production

# Helm
helm install my-app ./my-app -f values-prod.yaml
helm upgrade my-app ./my-app -f values-prod.yaml
helm rollback my-app 1
helm list -n production
```
