# Vagrant Variables
# Configuration for simple 3-node Kubernetes cluster

# Node Configuration
WORKER_NODES_COUNT = 2
MEMORY_PER_NODE = 2048
CPUS_PER_NODE = 2

# Network Configuration
PRIVATE_NETWORK_IP_PREFIX = "192.168.56."

# Box Configuration
VM_BOX = "ubuntu/jammy64"
