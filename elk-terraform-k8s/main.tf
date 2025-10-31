terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = var.kubectl_context != "" ? var.kubectl_context : null
}

resource "null_resource" "apply_manifest" {
  provisioner "local-exec" {
    command = <<EOT
      set -euo pipefail
      echo "==> Applying Kubernetes manifest: ${local.manifest_path}"
      if [ -n "${var.kubectl_context}" ]; then
        kubectl --context="${var.kubectl_context}" apply -f "${local.manifest_path}"
      else
        kubectl apply -f "${local.manifest_path}"
      fi
    EOT
  }

  # No destroy provisioner — Terraform will not automatically delete manifests
}

output "deployment_status" {
  value = "Deployment applied using manifest: ${local.manifest_path}"
}

