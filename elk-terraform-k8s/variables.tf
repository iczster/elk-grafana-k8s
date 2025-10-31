variable "kubectl_context" {
  description = "Kubernetes context to use (optional)"
  type        = string
  default     = ""
}

locals {
  manifest_path = "${path.module}/full-stack-deployment.yaml"
}

