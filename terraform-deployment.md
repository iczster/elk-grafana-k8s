# 📘 Terraform Deployment Guide — ELK + Grafana + Metrics Generator (Kubernetes on Docker Desktop)

## 🧭 Overview

This document explains the terraform module that deploys a working ELK + Grafana stack to a local Kubernetes cluster (Docker Desktop) by invoking ```kubectl apply``` against the single combined manifest (```full-stack-deployment.yaml```). 

This approach is intentionally robust for a local PoC and avoids Terraform provider mismatches and uses ```kubectl``` to apply and remove the Kubernetes resources. 

The module also runs ```kubectl delete -f``` when you run terraform destroy, so you can tear down cleanly.

A minimal Terraform module (elk_k8s) with:

* main.tf (null_resource that applies/deletes the manifest)
* variables.tf
* outputs.tf
* A ```full-stack-deployment.yaml``` (with Grafana provisioning + dashboard included)
* Clear usage instructions.

```NOTE:``` This has all been built, deployed and tested on the following reference stack to validate functionality and feasability. Some refactoring will be needed to deploy into our GCP environment.

* Docker Desktop version ```4.49.0 (208700)```
* Docker version ```28.5.1```
* K8s Engine version ```v1.34.1```
* MacOS Tahoe version ```26.0.1```
* Terraform (latest stable ```v1.13.4```) 


## 1. Directory Structure

```lua
elk-terraform-k8s/
├─ full-stack-deployment.yaml    <-- the Kubernetes manifest
├─ main.tf                       <-- terraform module apply/destroy logic
├─ variables.tf                  <-- variables to be used 
└─ outputs.tf                    <-- terraform outputs
```

## 2. Terraform files

```main.tf```

```hcl
terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "null" {}

variable "manifest_path" {
  description = "Path to the combined Kubernetes manifest (full-stack-deployment.yaml). Can be relative to module."
  type        = string
  default     = "${path.module}/full-stack-deployment.yaml"
}

variable "kubectl_context" {
  description = "Optional kubectl context to use (if empty, kubectl default context is used)."
  type        = string
  default     = ""
}

# Read the manifest for nicer logging (optional)
data "local_file" "manifest" {
  filename = var.manifest_path
}

# Apply the manifest on create
resource "null_resource" "apply_manifest" {
  # changing the file content will force a re-apply
  triggers = {
    manifest_sha256 = filesha256(var.manifest_path)
    kube_context    = var.kubectl_context
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT
set -euo pipefail
echo "==> Applying Kubernetes manifest: ${var.manifest_path}"
if [ -n "${var.kubectl_context}" ]; then
  kubectl --context="${var.kubectl_context}" apply -f "${var.manifest_path}"
else
  kubectl apply -f "${var.manifest_path}"
fi
EOT
  }

  # cleanup on destroy
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = <<EOT
set -euo pipefail
echo "==> Deleting Kubernetes manifest: ${var.manifest_path}"
if [ -n "${var.kubectl_context}" ]; then
  kubectl --context="${var.kubectl_context}" delete -f "${var.manifest_path}" --ignore-not-found
else
  kubectl delete -f "${var.manifest_path}" --ignore-not-found
fi
EOT
  }
}

output "manifest_path" {
  description = "Path to the manifest applied by Terraform"
  value       = var.manifest_path
}

output "kubectl_context" {
  description = "kubectl context used (empty = default)"
  value       = var.kubectl_context
}
```

```Notes:```

* This module uses the null_resource+local-exec pattern to call kubectl. That is the most reliable approach for a local Kubernetes PoC where ```kubectl``` is already configured (Docker Desktop).
* The resource triggers use the manifest SHA so changing the manifest causes re-apply

```variables.tf```

```hcl
variable "manifest_path" {
  description = "Path to the combined Kubernetes manifest (full-stack-deployment.yaml)."
  type        = string
  default     = "${path.module}/full-stack-deployment.yaml"
}

variable "kubectl_context" {
  description = "Optional kubectl context to use (if empty, kubectl default context is used)."
  type        = string
  default     = ""
}
```

```outputs.tf```

```hcl
output "grafana_url" {
  description = "URL to open Grafana (NodePort 30001)."
  value       = "http://localhost:30001"
}

output "kibana_url" {
  description = "URL to open Kibana (NodePort 30002)."
  value       = "http://localhost:30002"
}

output "elasticsearch_url" {
  description = "URL for Elasticsearch (NodePort 30200)."
  value       = "http://localhost:30200"
}
```

```full-stack-deployment.yaml```

The combined working manifest (comibation of the single .yaml files located in ```./manual-deployment```

* Namespace ```elk```
* Elasticsearch (HTTP-only, NodePort 30200)
* Logstash (ClusterIP + pipeline config)
* Kibana (NodePort 30002)
* Grafana (NodePort 30001) with provisioning ConfigMaps and an auto-loading dashboard
* Custom Metrics generator (per-second)

```yaml
# -------------------- full-stack-deployment.yaml --------------------
# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: elk
---
# Elasticsearch
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
        image: docker.elastic.co/elasticsearch/elasticsearch:8.14.0
        ports:
          - containerPort: 9200
        env:
          - name: discovery.type
            value: single-node
          - name: xpack.security.enabled
            value: "false"
          - name: xpack.security.http.ssl.enabled
            value: "false"
          - name: xpack.security.transport.ssl.enabled
            value: "false"
          - name: ES_JAVA_OPTS
            value: "-Xms512m -Xmx512m"
        volumeMounts:
          - name: es-data
            mountPath: /usr/share/elasticsearch/data
      volumes:
        - name: es-data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: elk
spec:
  selector:
    app: elasticsearch
  type: NodePort
  ports:
    - port: 9200
      targetPort: 9200
      nodePort: 30200
---
# Logstash
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstash-pipeline
  namespace: elk
data:
  logstash.conf: |
    input {
      http {
        port => 5044
      }
    }

    filter {
      json { source => "message" }
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
        image: docker.elastic.co/logstash/logstash:8.14.0
        ports:
          - containerPort: 5044
        volumeMounts:
          - name: logstash-pipeline
            mountPath: /usr/share/logstash/pipeline
      volumes:
        - name: logstash-pipeline
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
    - port: 5044
      targetPort: 5044
---
# Kibana
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
        image: docker.elastic.co/kibana/kibana:8.14.0
        ports:
          - containerPort: 5601
        env:
          - name: ELASTICSEARCH_HOSTS
            value: "http://elasticsearch:9200"
---
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: elk
spec:
  selector:
    app: kibana
  type: NodePort
  ports:
    - port: 5601
      targetPort: 5601
      nodePort: 30002
---
# Grafana (with provisioning + dashboard)
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-provisioning
  namespace: elk
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Elasticsearch
        type: elasticsearch
        access: proxy
        url: http://elasticsearch:9200
        isDefault: true
        jsonData:
          timeField: "@timestamp"

  dashboards.yaml: |
    apiVersion: 1
    providers:
      - name: 'default'
        folder: ''
        type: file
        disableDeletion: false
        updateIntervalSeconds: 10
        options:
          path: /var/lib/grafana/dashboards
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: elk
data:
  metrics-dashboard.json: |
    {
      "id": null,
      "uid": "per-second-metrics",
      "title": "Per Second Metrics",
      "timezone": "browser",
      "schemaVersion": 36,
      "version": 1,
      "refresh": "1s",
      "panels": [
        {
          "type": "timeseries",
          "title": "Live Metrics per Second",
          "targets": [
            {
              "refId": "A",
              "datasource": {
                "type": "elasticsearch",
                "uid": "-100"
              },
              "timeField": "@timestamp",
              "metrics": [
                { "id": "1", "type": "avg", "field": "metric" }
              ],
              "bucketAggs": [
                {
                  "type": "date_histogram",
                  "id": "2",
                  "field": "@timestamp",
                  "settings": {
                    "interval": "1s",
                    "min_doc_count": 1
                  }
                }
              ]
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "none",
              "color": {
                "mode": "palette-classic"
              }
            },
            "overrides": []
          },
          "options": {
            "legend": {
              "displayMode": "table",
              "placement": "bottom"
            }
          },
          "gridPos": {
            "h": 12,
            "w": 24,
            "x": 0,
            "y": 0
          }
        }
      ],
      "time": {
        "from": "now-5m",
        "to": "now"
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
        image: grafana/grafana:10.0.0
        ports:
          - containerPort: 3000
        env:
          - name: GF_SECURITY_ADMIN_USER
            value: admin
          - name: GF_SECURITY_ADMIN_PASSWORD
            value: admin
        volumeMounts:
          - name: grafana-provisioning
            mountPath: /etc/grafana/provisioning
          - name: grafana-dashboards
            mountPath: /var/lib/grafana/dashboards
      volumes:
        - name: grafana-provisioning
          configMap:
            name: grafana-provisioning
        - name: grafana-dashboards
          configMap:
            name: grafana-dashboards
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: elk
spec:
  selector:
    app: grafana
  type: NodePort
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30001
---
# Metrics generator (per-second)
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
        command:
          - /bin/sh
          - -c
          - |
            while true; do
              TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ");
              VALUE=$((RANDOM % 100));
              echo "{\"@timestamp\":\"$TS\", \"metric\":$VALUE}" | \
              wget --header="Content-Type: application/json" \
                   --post-data=- http://logstash:5044 -O - -q;
              sleep 1;
            done
# ---------------------------------------------------------
```

## 3. How to use the module

1. Ensure:
* Docker Desktop is running and Kubernetes enabled.
* kubectl is configured and points to Docker Desktop (check kubectl config current-context and kubectl get nodes).
* You have terraform installed.
2. The three Terraform files (```main.tf```, ```variables.tf```, ```outputs.tf```) and ```full-stack-deployment.yaml``` can be located in folder ```elk-terraform-k8s```
3. Initialize and apply:
```bash
cd elk-terraform-k8s
terraform init
terraform apply -auto-approve
```

Terraform will run ```kubectl apply -f full-stack-deployment.yaml``` and wait for the pods to start:

```bash
kubectl get pods -n elk -w
# or check once: kubectl get pods -n elk
```

4. Open the UIs:
Grafana: http://localhost:30001 (admin/admin)
Kibana: http://localhost:30002
Elasticsearch: http://localhost:30200

5. To remove the stack:

```bash
terraform destroy -auto-approve
```

That runs kubectl delete -f elk-stack.yaml and removes the namespace objects

## 4. Additional notes and troubleshooting

* If terraform apply errors because ```kubectl``` is not available on PATH, install kubectl or ensure your shell PATH includes it.
* If pods are CrashLooping:
  * Check logs: ```kubectl logs -n elk deployment/elasticsearch```
  * Common quick fixes for Elasticsearch on Docker Desktop:
  * vm.max_map_count — run:
  ```bash
  docker run --rm --privileged --pid=host alpine:3.17 sysctl -w vm.max_map_count=262144
  ```
* If still failing, check pod logs for messages about memory, disk, or bootstrapping.
* If Grafana dashboard does not immediately show data:
  * Ensure metrics-generator is running and sending to Logstash:
  ```bash
  kubectl logs -n elk deployment/metrics-generator -f
  kubectl logs -n elk deployment/logstash -f
  ```
* Ensure ElasticSearch has indices:
  ```bash
  curl http://localhost:30200/_cat/indices
  ```

