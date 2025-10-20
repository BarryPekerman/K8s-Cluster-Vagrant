#!/bin/bash

# =================================================================
# Local Kubernetes Cluster Setup Script
# =================================================================
# This script automates the setup of a local Kubernetes cluster
# using Vagrant and Ansible.
# =================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/setup.log"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_deps=()
    
    if ! command_exists vagrant; then
        missing_deps+=("vagrant")
    fi
    
    if ! command_exists vboxmanage; then
        missing_deps+=("virtualbox")
    fi
    
    if ! command_exists ansible; then
        missing_deps+=("ansible")
    fi
    
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_status "Please install the missing dependencies and run the script again."
        print_status "Installation instructions:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "vagrant")
                    echo "  - Vagrant: https://www.vagrantup.com/downloads"
                    ;;
                "virtualbox")
                    echo "  - VirtualBox: https://www.virtualbox.org/wiki/Downloads"
                    ;;
                "ansible")
                    echo "  - Ansible: https://docs.ansible.com/ansible/latest/installation_guide/index.html"
                    ;;
                "git")
                    echo "  - Git: https://git-scm.com/downloads"
                    ;;
            esac
        done
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to check system resources
check_system_resources() {
    print_status "Checking system resources..."
    
    # Check available memory (simplified check)
    local available_memory
    if command_exists free; then
        available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
        if [ "$available_memory" -lt 6000 ]; then
            print_warning "Available memory ($available_memory MB) is less than recommended (6GB)"
            print_warning "The cluster may not start properly or perform poorly"
        fi
    fi
    
    # Check available disk space
    local available_space
    available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 20 ]; then
        print_warning "Available disk space (${available_space}GB) is less than recommended (20GB)"
    fi
    
    print_success "System resource check completed"
}

# Function to clean up any existing cluster
cleanup_existing_cluster() {
    print_status "Checking for existing cluster..."
    
    if [ -f "${PROJECT_DIR}/.vagrant" ]; then
        print_warning "Found existing Vagrant environment"
        read -p "Do you want to destroy the existing cluster? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Destroying existing cluster..."
            cd "$PROJECT_DIR"
            vagrant destroy -f
            print_success "Existing cluster destroyed"
        else
            print_status "Keeping existing cluster, skipping setup"
            exit 0
        fi
    fi
}

# Function to start the cluster
start_cluster() {
    print_status "Starting Kubernetes cluster..."
    log_message "Starting cluster setup"
    
    cd "$PROJECT_DIR"
    
    # Start Vagrant VMs
    print_status "Creating and starting VMs..."
    vagrant up --no-provision
    
    # Provision with Ansible
    print_status "Provisioning cluster with Ansible..."
    vagrant provision
    
    print_success "Cluster provisioning completed"
    log_message "Cluster setup completed successfully"
}

# Function to verify cluster health
verify_cluster() {
    print_status "Verifying cluster health..."
    
    # Wait a bit for services to stabilize
    sleep 30
    
    # Check if we can connect to the cluster
    if vagrant ssh control-plane -c "kubectl get nodes" >/dev/null 2>&1; then
        print_success "Cluster is healthy and accessible"
        
        # Show cluster status
        print_status "Cluster status:"
        vagrant ssh control-plane -c "kubectl get nodes"
        
        print_status "System pods status:"
        vagrant ssh control-plane -c "kubectl get pods -n kube-system"
        
        print_status "Monitoring stack status:"
        vagrant ssh control-plane -c "kubectl get pods -n monitoring" 2>/dev/null || print_warning "Monitoring stack not ready yet"
        
    else
        print_error "Cluster health check failed"
        print_status "Check the logs and try running: vagrant ssh control-plane -c 'kubectl get nodes'"
        return 1
    fi
}

# Function to setup kubectl on host
setup_kubectl() {
    print_status "Setting up kubectl on host machine..."
    
    # Create .kube directory if it doesn't exist
    mkdir -p ~/.kube
    
    # Copy kubeconfig from control plane
    vagrant ssh control-plane -c "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/local-cluster-config
    
    print_success "kubeconfig copied to ~/.kube/local-cluster-config"
    print_status "To use kubectl from host:"
    echo "  export KUBECONFIG=~/.kube/local-cluster-config"
    echo "  kubectl get nodes"
}

# Function to show access information
show_access_info() {
    print_success "Cluster setup completed successfully!"
    echo
    print_status "Access Information:"
    echo "  Control Plane: vagrant ssh control-plane"
    echo "  Worker Nodes:  vagrant ssh worker-1, vagrant ssh worker-2"
    echo
    print_status "Monitoring URLs:"
    echo "  Grafana:     http://192.168.56.10:30000 (admin/prom-operator)"
    echo "  Prometheus:  http://192.168.56.10:30001"
    echo "  Alertmanager: http://192.168.56.10:30002"
    echo
    print_status "Useful Commands:"
    echo "  Check cluster: vagrant ssh control-plane -c 'kubectl get nodes'"
    echo "  View logs:     vagrant ssh control-plane -c 'kubectl logs -n monitoring <pod-name>'"
    echo "  Stop cluster:  vagrant halt"
    echo "  Start cluster: vagrant up"
    echo "  Destroy:       vagrant destroy -f"
    echo
    print_status "Next Steps:"
    echo "  1. Access the cluster: vagrant ssh control-plane"
    echo "  2. Deploy your applications"
    echo "  3. Monitor with Grafana: http://192.168.56.10:30000"
}

# Function to handle errors
handle_error() {
    print_error "Setup failed at step: $1"
    print_status "Check the log file: $LOG_FILE"
    print_status "Common troubleshooting steps:"
    echo "  1. Check system resources (RAM, disk space)"
    echo "  2. Ensure VirtualBox is running"
    echo "  3. Check network connectivity"
    echo "  4. Review Vagrant logs: vagrant up --debug"
    exit 1
}

# Main execution
main() {
    print_status "Starting Local Kubernetes Cluster Setup"
    print_status "Project directory: $PROJECT_DIR"
    print_status "Log file: $LOG_FILE"
    echo
    
    # Initialize log file
    echo "=== Local Kubernetes Cluster Setup Log ===" > "$LOG_FILE"
    log_message "Setup script started"
    
    # Run setup steps
    check_prerequisites || handle_error "Prerequisites check"
    check_system_resources || handle_error "System resources check"
    cleanup_existing_cluster || handle_error "Cleanup existing cluster"
    start_cluster || handle_error "Start cluster"
    verify_cluster || handle_error "Verify cluster"
    setup_kubectl || print_warning "kubectl setup failed (optional)"
    show_access_info
    
    log_message "Setup script completed successfully"
    print_success "Setup completed! Check $LOG_FILE for detailed logs."
}

# Trap errors
trap 'handle_error "Unexpected error"' ERR

# Run main function
main "$@"

