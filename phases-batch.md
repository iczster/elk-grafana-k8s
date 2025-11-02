# Phased Delivery Plan – Per Second Metrics (ELK/Grafana POC)

## 📘 Summary

The purpose of this Proof of Concept (POC) instance is to establish a foundation for an **immutable, per-second metrics platform** leveraging the ELK stack (Elasticsearch, Logstash, Kibana) and Grafana for visualization.  

This environment is **intentionally transient** and designed to be **rebuilt on a regular basis** to maintain:
- Optimal performance and minimal technical debt.  
- Reduced storage overhead by expiring or discarding historical data older than **72 hours**.  
- Consistency and reliability through repeatable, automated deployments.

The POC supports a forward-looking goal of implementing **Infrastructure as Code (IaC)** practices that enforce immutability, automation, and clear separation of concerns across metrics, indices, and dashboards.

---

## 🧩 Phase 1 – Concept Build and Feasibility Validation ✅ *(Complete)*

### Objective
Establish a reference architecture and validate the feasibility of deploying a **fully automated observability stack** using IaC principles.

### Deliverables
- Initial deployment scripts using **Terraform, Kubernetes, and ELK**.
- Automated provisioning of:
  - **Elasticsearch indices** for per-second metric ingestion.
  - **Logstash pipelines** to collect and transform data.
  - **Grafana dashboards** pre-configured to visualize real-time metrics.
  - **Custom Metrics Generator** per second random metric generator to populate dashboard and validate build integrity
- Validation of end-to-end connectivity between all components (metric generator → Logstash → Elasticsearch → Grafana).
- Deployment automation validated using local Kubernetes via Docker Desktop.

### Outcome
This phase confirmed that a **single command (Terraform Apply)** can fully provision and tear down the stack, including dashboards and data sources — proving the viability of a “stack as code” approach.

---

## 🌐 Phase 2 – Refactor for GCP GKE Environment 🚧 *(In Progress)*

### Objective
Refactor and redeploy the stack to run natively in **Google Kubernetes Engine (GKE)** using a **dedicated namespace (`elk-stack`)**, with appropriate scaling and performance considerations.

### Key Activities
1. **Migration to GKE:**
   - Adapt Helm charts and Terraform modules to reference existing GKE contexts and namespaces.
   - Ensure components run as pods within the cluster (1 replica per component initially).
   - Replace local NodePort exposure with GCP LoadBalancer services or internal ingress configurations.

2. **Performance and Scaling:**
   - Benchmark ingestion throughput for per-second metrics.
   - Tune Elasticsearch heap and JVM settings.
   - Introduce Horizontal Pod Autoscalers (HPAs) for Logstash and Elasticsearch.
   - Evaluate persistent volume configurations using GCP-managed storage classes.

3. **Security and Namespace Isolation:**
   - Ensure all resources deploy under the `elk-stack` namespace.
   - Use GCP IAM roles and Kubernetes RBAC for controlled access to metrics.
   - Restrict Grafana and Kibana access to specific service accounts or network ranges.

4. **Automated Lifecycle:**
   - Enable automated cleanup of old indices (older than 72 hours).
   - Extend Terraform modules to support automated teardown and rebuild triggers.

### Expected Outcome
A **cloud-native, immutable monitoring stack** capable of handling production-grade per-second metrics, rebuilt periodically with zero manual intervention and minimal data retention overhead. Ensure the deployment pattern is vetted and fit for purpose by CPT

---

## 🧭 Phase 3 – Team-Based Consumption and Isolation (Future Roadmap)

### Objective
Enable multiple technology teams to consume the platform independently, using **segmented ELK instances and index naming conventions** to maintain data isolation and governance.

### Strategy
- Provision dedicated stacks for each major technology domain or team using namespace-level or Helm release-level separation.
- Example:
  - `elk-stack-sre` → Metrics pipeline for Site Reliability Engineering (SRE) team.
  - `elk-stack-gaming` → Dedicated stack for Gaming platform monitoring.
- Each stack includes:
  - Independent Elasticsearch cluster and indices.
  - Separate Logstash pipelines and inputs.
  - Isolated Grafana instances and dashboards pre-linked to their own data sources (or use on-prem if viable)

### Implementation Approach
1. **Modularization via Helm and Terraform:**
   - Parameterize Helm values for team-specific namespaces and resource naming.
   - Reuse the same IaC modules for rapid stack instantiation.

2. **Index and Data Segregation:**
   - Apply team-specific index prefixes (e.g., `sre-metrics-*`, `gaming-metrics-*`).
   - Ensure access control via role-based index patterns and API tokens.

3. **Governance and Access:**
   - Configure separate Grafana organizations for each team (?))
   - Enforce RBAC rules via GCP IAM bindings and Kubernetes service accounts.

### Expected Outcome
A scalable model enabling each team to:
- Deploy an **isolated per second metrics stack on demand**.
- Consume real-time per-second metrics securely.
- Avoid cross-team interference while retaining operational autonomy.

---

## 🔁 Summary of Phases

| Phase | Description | Status | Key Output |
|-------|--------------|--------|-------------|
| **Phase 1** | Concept build of full stack using Terraform + Docker Desktop | ✅ Complete | Automated ELK + Grafana stack |
| **Phase 2** | Migration to GCP GKE with scaling and namespace isolation | 🚧 In Progress | Refactored IaC + GKE-native deployment |
| **Phase 3** | Multi-team consumption via dedicated ELK stacks | ⏳ Planned | Segmented stacks (e.g., `elk-stack-sre`, `elk-stack-gaming`) |

---

## 🧱 Next Steps
- Complete Phase 2 testing in the existing GKE cluster.
- Validate scaling benchmarks and HPA behaviors.
- Begin modularization for Phase 3 team adoption.

---

> **Note:** All environments in this project are intended for **short-lived, transient workloads** to maintain immutability and system performance.  
> Persistent or historical storage beyond 72 hours is explicitly **out of scope** for this POC.
> Decision point on standing up dedicated `short lived` Grafana instances for each team to be decided vs using our Enterprise on-prem deployment
