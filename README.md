# 🧭 Overview

This project demonstrates a **per-second metric ingestion and visualization stack** using:

- **Elasticsearch**, **Logstash**, **Kibana** (ELK)
- **Grafana** for dashboards
- A **Metrics Generator** producing random metrics every second
- Full deployment automated with **Terraform**
- **Docker Desktop with Kubernetes** on macOS (for local PoC)
- Auto-provisioned Grafana data source and dashboard

The goal is to validate **end-to-end metric flow** and **real-time visualization** using a modern observability stack. A scalability focus will be added, this is purely a working proof of concept.

---

## ⚙️  Architecture

```plaintext
+-------------------------+
| Metrics Generator       |
| (random per-sec data)   |
+-----------+-------------+
            |
            v  HTTP JSON
+-----------+-------------+
| Logstash (ClusterIP)    |
| Parses + outputs to ES  |
+-----------+-------------+
            |
            v
+-----------+-------------+
| Elasticsearch (NodePort)|
| Stores metrics index    |
+-----------+-------------+
            |
     +------+------+
     |             |
     v             v
+----+----+   +----+----+
| Kibana  |   | Grafana |
| (30002) |   | (30001) |
| Visual  |   | Auto DS |
+---------+   +---------+

## NodePorts:

| Component     | Port  | URL                                              |
| ------------- | ----- | ------------------------------------------------ |
| Elasticsearch | 30200 | [http://localhost:30200](http://localhost:30200) |
| Kibana        | 30002 | [http://localhost:30002](http://localhost:30002) |
| Grafana       | 30001 | [http://localhost:30001](http://localhost:30001) |

```

## 🏗️ Prerequisites

* macOS with Docker Desktop (Kubernetes enabled)
* kubectl CLI
* Terraform ≥ 1.0.0
* Internet connection (for pulling container images)

Check your setup:

```bash

docker info | grep Kubernetes
kubectl version --client
terraform -version
```


## 🚀 Deployment Steps

1. Clone the Repository

```bash
git clone https://github.com/your-org/elk-terraform.git
cd elk-terraform
```
2. Initialize Terraform

```bash
terraform init
```

3. Apply the Deployment

```bash
terraform apply -auto-approve
```
Terraform will:

* Create namespace elk
* Apply the full Kubernetes manifest (elk-stack.yaml)
* Deploy all components (Elasticsearch, Logstash, Kibana, Grafana, Metrics Generator)
* Auto-provision the Grafana dashboard


4. Validate Pods

```bash
kubectl get pods -n elk
```

Expected output (all running):

```sql
elasticsearch-xxxxx   1/1   Running
logstash-xxxxx        1/1   Running
kibana-xxxxx          1/1   Running
grafana-xxxxx         1/1   Running
metrics-generator-xxx 1/1   Running
```

## 🌐 Accessing the Stack

| Service           | URL                                              | Description                |
| ----------------- | ------------------------------------------------ | -------------------------- |
| **Grafana**       | [http://localhost:30001](http://localhost:30001) | Default user `admin/admin` |
| **Kibana**        | [http://localhost:30002](http://localhost:30002) | Explore ES indices         |
| **Elasticsearch** | [http://localhost:30200](http://localhost:30200) | REST API endpoint          |

## 📊 Grafana Auto Dashboard

Grafana automatically provisions:

* Elasticsearch Data Source
* Dashboard: Per Second Metrics
  
It displays a live time series chart (```metric``` field, 1s interval).
Open http://localhost:30001 → Per Second Metrics Dashboard

## 🧪 Tests and Validation

1. Verifiy Metric Flow

Check the metric generator logs:

```bash
kubectl logs -n elk deployment/metrics-generator -f
```

You should see JSON output every second:

```json
{"@timestamp":"2025-10-30T15:50:00Z", "metric":42}
```

2. Check Logstash ingestion

```bash
kubectl logs -n elk deployment/logstash -f
```

Expected:
```perl
{
  "@timestamp" => "2025-10-30T15:50:00Z",
  "metric" => 42
}
```
3. Verify ElasticSearch Data

```bash
curl http://localhost:30200/_cat
curl http://localhost:30200/_cat/indices
```

Look for:

```
metrics-2025.10.30
```

4. Verify Grafana Installation

* Visit Grafana → “Per Second Metrics” Dashboard
* You should see a real-time updating line chart

<ADD RELATIVE SCREENSHOT HERE>

## 🧹 Cleanup
To destroy all resources:

```bash
terraform destroy -auto-approve
```

## 🧩 Repository Structure

```bash
elk-grafana-k8s/
├── elk-stack.yaml             # Full Kubernetes manifest
├── main.tf                    # Terraform apply/destroy logic
├── variables.tf               # Variable and data lookups
├── outputs.tf                 # Terraform outputs
├── README.md                  # This guide
└── technical_specification.md # Detailed technical design
```

## 🧠 Troubleshooting

1. Elasticsearch won’t start (CrashLoopBackOff):
Set kernel param for mmap:


```bash
docker run --rm --privileged --pid=host alpine:3.17 sysctl -w vm.max_map_count=262144
```

2. Empty Grafana dashboard:
Ensure data is reaching Elasticsearch:

```bash
curl http://localhost:30200/_cat/indices
```

3. NodePorts unavailable:
Change NodePorts in ```elk-stack.yaml``` to available ports (30000–32767)

## 🏁 Summary
✅ Proof-of-Concept Phase 1 validated:

* Per-second metrics → Logstash → Elasticsearch
* Auto-provisioned Grafana dashboard
* Local, reproducible Kubernetes deployment using Terraform

| Component            | Type       | Access                    | Notes                          |
| -------------------- | ---------- | ------------------------- | ------------------------------ |
| **Elasticsearch**    | Deployment | ClusterIP (9200 internal) | Stores per-second metrics      |
| **Logstash**         | Deployment | ClusterIP (5044 internal) | Ingests metrics                |
| **Kibana**           | Deployment | NodePort 30002            | Explore data                   |
| **Grafana**          | Deployment | NodePort 30001            | Dashboards/alerts              |
| **Metric Generator** | Deployment | Internal                  | Sends random metrics every 1s  |


## 🧩 Next Steps

* Refactor to deploy into Google Kubernetes Engine
* Image Attestation
* Add Terraform Kubernetes provider to define resources natively.
* Introduce Helm for managed lifecycle and scaling.
* Enable PersistentVolumes for Elasticsearch data retention.
* Secure endpoints with basic auth + TLS.
* Scalability improvements & Testing
* Backend transient ingest cleanup automation (e.g. 48 hours max, indices maintenance)

```NOTE```

* Check the ```technical_specifications.md``` file for additional information
* If you want to bypass terraform the step-by-step instructions are included in the ```manual-deployment.md file using `kubectl apply -f <manifest file>``` via the CLI



