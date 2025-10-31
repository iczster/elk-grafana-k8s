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

