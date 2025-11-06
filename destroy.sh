#!/bin/bash
# Destroy helper script

set -euo pipefail
echo "⚠️  WARNING: This will delete the ELK stack Kubernetes resources and run 'terraform destroy'."
read -p "Are you sure you want to continue? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  echo "Deleting elk namespace ..."
  kubectl delete namespace elk --ignore-not-found
  echo "Running terraform destroy ..."
  terraform destroy -auto-approve || echo "terraform destroy failed or not initialized"
  echo "Done."
else
  echo "Cancelled."
fi
