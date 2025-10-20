#!/bin/bash

# =================================================================
# Local Kubernetes Cluster Teardown Script
# =================================================================
# This script safely destroys the local Kubernetes cluster
# and cleans up all associated resources.
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
LOG_FILE="${PROJECT_DIR}/teardown.log"

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

# Function to check if cluster exists
check_cluster_exists() {
    if [ ! -f "${PROJECT_DIR}/.vagrant" ]; then
        print_warning "No Vagrant environment found. Nothing to tear down."
        return 1
    fi
    return 0
}

# Function to get user confirmation
confirm_teardown() {
    print_warning "This will destroy the entire Kubernetes cluster and all data."
    print_warning "This action cannot be undone!"
    echo
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Teardown cancelled by user"
        exit 0
    fi
}

# Function to backup important data (optional)
backup_data() {
    print_status "Checking for important data to backup..."
    
    local backup_dir="${PROJECT_DIR}/backup-$(date +%Y%m%d-%H%M%S)"
    local has_data=false
    
    # Check if there are any custom resources or data
    if vagrant ssh control-plane -c "kubectl get namespaces | grep -v '^NAME\|kube-\|default\|monitoring\|cert-manager'" >/dev/null 2>&1; then
        print_warning "Found custom namespaces. Consider backing up your data."
        has_data=true
    fi
    
    if [ "$has_data" = true ]; then
        read -p "Do you want to backup cluster data before teardown? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Creating backup in $backup_dir"
            mkdir -p "$backup_dir"
            
            # Backup kubeconfig
            vagrant ssh control-plane -c "sudo cat /etc/kubernetes/admin.conf" > "$backup_dir/kubeconfig" 2>/dev/null || true
            
            # Backup cluster info
            vagrant ssh control-plane -c "kubectl get nodes -o yaml" > "$backup_dir/nodes.yaml" 2>/dev/null || true
            vagrant ssh control-plane -c "kubectl get namespaces -o yaml" > "$backup_dir/namespaces.yaml" 2>/dev/null || true
            
            print_success "Backup created in $backup_dir"
        fi
    fi
}

# Function to gracefully shutdown cluster
graceful_shutdown() {
    print_status "Performing graceful shutdown..."
    
    # Try to drain nodes if possible
    if vagrant ssh control-plane -c "kubectl get nodes" >/dev/null 2>&1; then
        print_status "Draining worker nodes..."
        vagrant ssh control-plane -c "kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data --force" 2>/dev/null || true
        vagrant ssh control-plane -c "kubectl drain worker-2 --ignore-daemonsets --delete-emptydir-data --force" 2>/dev/null || true
        
        print_status "Waiting for pods to terminate..."
        sleep 10
    fi
    
    # Stop VMs gracefully
    print_status "Stopping VMs gracefully..."
    cd "$PROJECT_DIR"
    vagrant halt
    print_success "VMs stopped gracefully"
}

# Function to destroy cluster
destroy_cluster() {
    print_status "Destroying cluster..."
    
    cd "$PROJECT_DIR"
    
    # Force destroy all VMs
    print_status "Destroying VMs and cleaning up resources..."
    vagrant destroy -f
    
    print_success "Cluster destroyed"
}

# Function to clean up local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    # Remove kubeconfig if it exists
    if [ -f ~/.kube/local-cluster-config ]; then
        rm -f ~/.kube/local-cluster-config
        print_status "Removed local kubeconfig"
    fi
    
    # Remove any generated files
    rm -f "${PROJECT_DIR}/ansible/join-command"
    print_status "Removed generated join command"
    
    # Clean up any temporary files
    find "$PROJECT_DIR" -name "*.log" -not -name "teardown.log" -delete 2>/dev/null || true
    print_status "Cleaned up temporary files"
}

# Function to clean up VirtualBox resources
cleanup_virtualbox() {
    print_status "Cleaning up VirtualBox resources..."
    
    # Remove any orphaned VMs
    local vms=("k8s-control-plane" "k8s-worker-1" "k8s-worker-2")
    
    for vm in "${vms[@]}"; do
        if vboxmanage list vms | grep -q "$vm"; then
            print_status "Removing orphaned VM: $vm"
            vboxmanage unregistervm "$vm" --delete 2>/dev/null || true
        fi
    done
    
    # Clean up any orphaned disks
    print_status "Cleaning up orphaned disks..."
    vboxmanage list hdds | grep -E "(k8s-|kubernetes)" | awk '{print $2}' | while read -r uuid; do
        if [ -n "$uuid" ]; then
            print_status "Removing orphaned disk: $uuid"
            vboxmanage closemedium disk "$uuid" --delete 2>/dev/null || true
        fi
    done
    
    print_success "VirtualBox cleanup completed"
}

# Function to verify cleanup
verify_cleanup() {
    print_status "Verifying cleanup..."
    
    # Check if Vagrant environment is gone
    if [ ! -f "${PROJECT_DIR}/.vagrant" ]; then
        print_success "Vagrant environment removed"
    else
        print_warning "Vagrant environment still exists"
    fi
    
    # Check if VMs are gone
    local vms=("k8s-control-plane" "k8s-worker-1" "k8s-worker-2")
    local remaining_vms=()
    
    for vm in "${vms[@]}"; do
        if vboxmanage list vms | grep -q "$vm"; then
            remaining_vms+=("$vm")
        fi
    done
    
    if [ ${#remaining_vms[@]} -eq 0 ]; then
        print_success "All VMs removed"
    else
        print_warning "Some VMs still exist: ${remaining_vms[*]}"
        print_status "You may need to manually remove them from VirtualBox"
    fi
    
    # Check disk usage
    local disk_usage
    disk_usage=$(du -sh "$PROJECT_DIR" 2>/dev/null | cut -f1)
    print_status "Project directory size: $disk_usage"
}

# Function to show cleanup summary
show_cleanup_summary() {
    print_success "Teardown completed successfully!"
    echo
    print_status "Cleanup Summary:"
    echo "  ✓ VMs destroyed"
    echo "  ✓ Local files cleaned"
    echo "  ✓ VirtualBox resources cleaned"
    echo "  ✓ Kubeconfig removed"
    echo
    print_status "Resources freed:"
    echo "  - ~6GB RAM"
    echo "  - ~6 CPU cores"
    echo "  - ~20GB disk space"
    echo
    print_status "To recreate the cluster:"
    echo "  ./scripts/setup.sh"
    echo
    print_status "Log file: $LOG_FILE"
}

# Function to handle errors
handle_error() {
    print_error "Teardown failed at step: $1"
    print_status "Check the log file: $LOG_FILE"
    print_status "Manual cleanup may be required:"
    echo "  1. Check VirtualBox for orphaned VMs"
    echo "  2. Remove .vagrant directory if it exists"
    echo "  3. Clean up any remaining files"
    exit 1
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -f, --force     Skip confirmation prompts"
    echo "  -q, --quiet     Suppress output (except errors)"
    echo "  -h, --help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0              # Interactive teardown"
    echo "  $0 --force      # Force teardown without prompts"
    echo "  $0 --quiet      # Quiet teardown"
}

# Parse command line arguments
FORCE=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    # Initialize log file
    echo "=== Local Kubernetes Cluster Teardown Log ===" > "$LOG_FILE"
    log_message "Teardown script started"
    
    if [ "$QUIET" = false ]; then
        print_status "Starting Local Kubernetes Cluster Teardown"
        print_status "Project directory: $PROJECT_DIR"
        print_status "Log file: $LOG_FILE"
        echo
    fi
    
    # Check if cluster exists
    if ! check_cluster_exists; then
        exit 0
    fi
    
    # Get confirmation unless forced
    if [ "$FORCE" = false ]; then
        confirm_teardown
    fi
    
    # Run teardown steps
    backup_data || print_warning "Backup failed or skipped"
    graceful_shutdown || print_warning "Graceful shutdown failed, continuing with force destroy"
    destroy_cluster || handle_error "Destroy cluster"
    cleanup_local_files || print_warning "Local cleanup failed"
    cleanup_virtualbox || print_warning "VirtualBox cleanup failed"
    verify_cleanup || print_warning "Cleanup verification failed"
    
    if [ "$QUIET" = false ]; then
        show_cleanup_summary
    fi
    
    log_message "Teardown script completed successfully"
}

# Trap errors
trap 'handle_error "Unexpected error"' ERR

# Run main function
main "$@"

