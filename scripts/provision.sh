#!/bin/bash

# =================================================================
# Provision Kubernetes Cluster with Ansible
# =================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if VMs are running
print_status "Checking if VMs are running..."
if ! vagrant status | grep -q "running"; then
    print_status "Starting VMs..."
    vagrant up --no-provision
else
    print_status "VMs are already running"
fi

# Run Ansible playbook
print_status "Running Ansible playbook..."
# Generate ssh-config for Ansible to use Vagrant's dynamic ports/keys
vagrant ssh-config > ssh-config
ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i ansible/inventory ansible/playbook.yml

print_success "Cluster provisioning completed!"
print_status "Check cluster status: vagrant ssh control-plane -c 'kubectl get nodes'"
