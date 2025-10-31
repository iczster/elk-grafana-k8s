
# 📘 Manual Deployment Guide — ELK + Grafana + Metrics Generator (Kubernetes on Docker Desktop)

## 🧭 Overview

This document explains how to manually deploy a **working ELK + Grafana stack** with a **per-second metric generator** on **Kubernetes (Docker Desktop for macOS)** using `kubectl` and individual YAML manifests.

You will:
- Deploy Elasticsearch, Logstash, Kibana, Grafana, and a metrics generator
- Configure Logstash → Elasticsearch → Grafana pipeline
- Verify metric ingestion and visualization
- Access all UIs via `localhost` NodePorts

---

## ⚙️ Prerequisites

- macOS with **Docker Desktop** (Kubernetes enabled)
- **kubectl** installed and configured
- Minimum 4 GB memory allocated to Docker Desktop
- Internet access to pull container images

Check your setup:
```bash
kubectl cluster-info
docker info | grep Kubernetes
```

## 🧭 Architecture Overview

```plaintext
+---------------------------+
|     Docker Desktop VM     |
|  (Kubernetes Enabled)     |
+-----------+---------------+
            |
            ▼
     [Kubernetes Cluster]
            |
            ├── elasticsearch (NodePort 30200, HTTP)
            ├── logstash (ClusterIP)
            ├── kibana (NodePort 30002)
            ├── grafana (NodePort 30001)
            └── metrics-generator (ClusterIP)
```

All pods run in namespace ```elk```

## 🧱 Directory Layout

You will have this files:

```cpp
manual-deployment/
├── 00-namespace.yaml
├── 01-elasticsearch.yaml
├── 02-logstash.yaml
├── 03-kibana.yaml
├── 04-grafana.yaml
├── 05-metrics-generator.yaml
└── manual-deployment.md
```
## 🚀 Step-by-Step Deployment

### Step 1 — Create Namespace

File: ```00-namespace.yaml```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: elk
```
Apply:
```bash
kubectl apply -f 00-namespace.yaml
```

Verify:
```bash
kubectl get ns
```
Expected:
```mathematica
elk   Active
```

### Step 2 — Deploy Elasticsearch
File: ```01-elasticsearch.yaml```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elasticsearch
  namespace: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
        - name: elasticsearch
          image: docker.elastic.co/elasticsearch/elasticsearch:8.15.0
          env:
            - name: discovery.type
              value: single-node
            - name: xpack.security.enabled
              value: "false"
            - name: ES_JAVA_OPTS
              value: "-Xms512m -Xmx512m"
          ports:
            - containerPort: 9200
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: elk
spec:
  type: NodePort
  selector:
    app: elasticsearch
  ports:
    - port: 9200
      targetPort: 9200
      nodePort: 30200
```
Apply:
```bash
kubectl apply -f 01-elasticsearch.yaml
```

Wait for startup:

```bash
kubectl get pods -n elk -w
```

Test connection:

Expected output:
```json
{
  "name" : "elasticsearch",
  "cluster_name" : "docker-cluster",
  "tagline" : "You Know, for Search"
}
```

### Step 3 — Deploy Logstash

File: ```02-logstash.yaml```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstash-pipeline
  namespace: elk
data:
  logstash.conf: |
    input {
      http {
        port => 8080
      }
    }
    filter {
      json {
        source => "message"
      }
    }
    output {
      elasticsearch {
        hosts => ["http://elasticsearch:9200"]
        index => "metrics-%{+YYYY.MM.dd}"
      }
      stdout { codec => rubydebug }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logstash
  namespace: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logstash
  template:
    metadata:
      labels:
        app: logstash
    spec:
      containers:
        - name: logstash
          image: docker.elastic.co/logstash/logstash:8.15.0
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: pipeline
              mountPath: /usr/share/logstash/pipeline/
      volumes:
        - name: pipeline
          configMap:
            name: logstash-pipeline
---
apiVersion: v1
kind: Service
metadata:
  name: logstash
  namespace: elk
spec:
  type: ClusterIP
  selector:
    app: logstash
  ports:
    - port: 8080
      targetPort: 8080
```

Apply:
```bash
kubectl apply -f 02-logstash.yaml
```

Verify:
```bash
kubectl get pods -n elk
kubectl logs -n elk deployment/logstash
```

Expected: No errors, pipeline started message visible

### Step 4 — Deploy Kibana

File: ```03-kibana.yaml```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
        - name: kibana
          image: docker.elastic.co/kibana/kibana:8.15.0
          env:
            - name: ELASTICSEARCH_HOSTS
              value: "http://elasticsearch:9200"
          ports:
            - containerPort: 5601
---
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: elk
spec:
  type: NodePort
  selector:
    app: kibana
  ports:
    - port: 5601
      targetPort: 5601
      nodePort: 30002
```

Apply:
```bash
kubectl apply -f 03-kibana.yaml
```

Wait & Verify:
```bash
kubectl get pods -n elk -w
```

Test connection:
```bash
curl http://localhost:30002/status -I
```

Then check:
```bash
kubectl get svc -n elk | grep kibana
```

You should see:
```nginx
kibana   NodePort   10.x.x.x   <none>   5601:30002/TCP
```

### Access Kibana UI:
👉 http://localhost:30002

### Step 5 — Deploy Grafana

File: ```04-grafana.yaml```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-provisioning
  namespace: elk
data:
  datasource.yaml: |
    apiVersion: 1
    datasources:
      - name: Elasticsearch
        type: elasticsearch
        access: proxy
        url: http://elasticsearch:9200
        jsonData:
          timeField: "@timestamp"
          interval: "1s"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard
  namespace: elk
data:
  dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Per Second Metrics",
        "panels": [
          {
            "type": "timeseries",
            "title": "Metric Values per Second",
            "targets": [
              {
                "datasource": "Elasticsearch",
                "query": "metric:*"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "short"
              }
            }
          }
        ]
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
        - name: grafana
          image: grafana/grafana:10.4.2
          ports:
            - containerPort: 3000
          env:
            - name: GF_SECURITY_ADMIN_USER
              value: admin
            - name: GF_SECURITY_ADMIN_PASSWORD
              value: admin
          volumeMounts:
            - name: provisioning
              mountPath: /etc/grafana/provisioning/datasources
            - name: dashboards
              mountPath: /var/lib/grafana/dashboards
      volumes:
        - name: provisioning
          configMap:
            name: grafana-provisioning
        - name: dashboards
          configMap:
            name: grafana-dashboard
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: elk
spec:
  type: NodePort
  selector:
    app: grafana
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30001
```

Apply:
```bash
kubectl apply -f 04-grafana.yaml
```

Then check:
```bash
kubectl get svc -n elk | grep grafana
```

You should now see:
```nginx
grafana   NodePort   10.x.x.x   <none>   3000:30001/TCP
```

### Access Grafana UI:
👉 http://localhost:30001
Login: admin / admin

### Step 6 — Deploy Metrics Generator

File: ```05-metrics-generator.yaml```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-generator
  namespace: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      app: metrics-generator
  template:
    metadata:
      labels:
        app: metrics-generator
    spec:
      containers:
        - name: metrics-generator
          image: busybox
          command: ["/bin/sh", "-c"]
          args:
            - >
              while true; do
                METRIC=$(shuf -i 1-100 -n 1);
                TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ");
                DATA="{\"@timestamp\":\"$TIMESTAMP\",\"metric\":$METRIC}";
                wget --header="Content-Type: application/json" \
                     --post-data="$DATA" \
                     -qO- logstash:8080;
                echo $DATA;
                sleep 1;
              done
```

Apply:
```bash
kubectl apply -f 05-metrics-generator.yaml
```

Check logs:
```bash
kubectl logs -n elk deployment/metrics-generator -f
```

Expected output (1/sec):

```json
{"@timestamp":"2025-10-30T16:00:00Z","metric":42}
```

### ✅ Verification Tests

| Step | Test          | Command                                               | Expected                  |
| ---- | ------------- | ----------------------------------------------------- | ------------------------- |
| 1    | Namespace     | `kubectl get ns`                                      | `elk` active              |
| 2    | Elasticsearch | `curl localhost:30200`                                | JSON info                 |
| 3    | Logstash      | `kubectl logs deploy/logstash -n elk`                 | Pipeline started          |
| 4    | Kibana        | Open [http://localhost:30002](http://localhost:30002) | Kibana UI                 |
| 5    | Grafana       | Open [http://localhost:30001](http://localhost:30001) | Grafana UI + dashboard    |
| 6    | Data flow     | `curl localhost:30200/_cat/indices?v`                 | `metrics-*` index         |
| 7    | Visualization | Grafana chart                                         | Live updates every second |


### 🌐 Access Points

| Service       | Type     | NodePort | URL                                              |
| ------------- | -------- | -------- | ------------------------------------------------ |
| Elasticsearch | NodePort | 30200    | [http://localhost:30200](http://localhost:30200) |
| Kibana        | NodePort | 30002    | [http://localhost:30002](http://localhost:30002) |
| Grafana       | NodePort | 30001    | [http://localhost:30001](http://localhost:30001) |


### 🧹 Cleanup

```bash
kubectl delete namespace elk
```


