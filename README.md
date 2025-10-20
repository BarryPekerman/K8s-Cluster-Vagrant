# Simple Kubernetes Cluster

A straightforward local Kubernetes cluster setup using **Vagrant** and **Ansible** for learning and development.

## 🏗️ **Architecture**

### **Simple 3-Node Cluster**
- **1 Control Plane** (192.168.56.10) - 2GB RAM, 2 CPUs
- **2 Worker Nodes** (192.168.56.11, 192.168.56.12) - 2GB RAM, 2 CPUs each
- **Total Resources**: 6GB RAM, 6 CPUs

### **Components**
- **Container Runtime**: containerd
- **CNI**: Calico for pod networking
- **Monitoring**: Prometheus + Grafana + AlertManager (via kube-prometheus-stack)
- **Ingress**: Not installed by default (see Next Steps)
- **Package Manager**: Helm

## 📋 **Prerequisites**

### **System Requirements**
- **RAM**: 8GB+ (6GB for cluster + 2GB for host)
- **CPU**: 6+ cores (6 for cluster + 2 for host)
- **Storage**: 20GB+ free space
- **Network**: Host-only network adapter

### **Required Software**
- [Vagrant](https://www.vagrantup.com/downloads) (2.3.0+)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (6.1+)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) (2.9+)

## 🚀 **Quick Start**

### **1. Start the Cluster**
```bash
# Start all VMs and provision with Ansible (runs automatically from control-plane)
vagrant up

# This will:
# - Create 3 VMs (1 control-plane + 2 workers)
# - Install Kubernetes components
# - Initialize the cluster
# - Join worker nodes
# - Deploy monitoring stack (cert-manager, metrics-server, kube-prometheus-stack)
```

### **2. Verify Cluster**
```bash
# Check cluster status
vagrant ssh control-plane -c "kubectl get nodes"

# Check system pods
vagrant ssh control-plane -c "kubectl get pods -n kube-system"

# Check monitoring stack
vagrant ssh control-plane -c "kubectl get pods -n monitoring"
```

### **3. Access the Cluster**
```bash
# SSH into control plane
vagrant ssh control-plane

# Or run kubectl commands directly
vagrant ssh control-plane -c "kubectl get nodes"
```

## 🔧 **Configuration**

### **Resource Allocation**
The cluster is configured with:
- **Control Plane**: 2GB RAM, 2 CPUs
- **Workers**: 2GB RAM, 2 CPUs each
- **Total**: 6GB RAM, 6 CPUs

### **Networking**
- **Pod CIDR**: 192.168.0.0/16
- **Service CIDR**: 10.96.0.0/12
- **CNI**: Calico with BGP

### **Monitoring**
- **Prometheus**: Metrics collection
- **Grafana**: Visualization (default admin password from secret; see below)
- **AlertManager**: Alert notifications (disabled by default in values)
- **Metrics Server**: Resource metrics

## 📊 **Monitoring Access**

### **Grafana Dashboard**
```bash
# Port forward to access Grafana
vagrant ssh control-plane -c "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"

# Access at: http://localhost:3000
# Username: admin
# Password: retrieve via:
#   vagrant ssh control-plane -c "kubectl -n monitoring get secret prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo"
```

### **Prometheus**
```bash
# Port forward to access Prometheus
vagrant ssh control-plane -c "kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"

# Access at: http://localhost:9090
```

## 🛠️ **Optional Features**

### **Ingress (Not installed by default)**
- Recommended controllers: NGINX Ingress or Traefik
- For bare metal LoadBalancer, install MetalLB and expose ingress via LoadBalancer or NodePort
- Example install (NGINX via Helm):
  - Add repo: `vagrant ssh control-plane -c "helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update"`
  - Install: `vagrant ssh control-plane -c "helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace --wait"`

### **Applications**
- Bring your own manifests or Helm charts and apply from the control-plane VM
  - Example: `vagrant ssh control-plane -c "kubectl apply -f <your-manifest>.yaml"`

## 🔄 **Management Commands**

### **Start/Stop Cluster**
```bash
# Start cluster
vagrant up

# Stop cluster
vagrant halt

# Restart cluster
vagrant reload
```

### **Destroy Cluster**
```bash
# Completely remove cluster
vagrant destroy -f
```

### **Check Status**
```bash
# Check VM status
vagrant status

# Check cluster health
vagrant ssh control-plane -c "kubectl get nodes"
```

## 🐛 **Troubleshooting**

### **Common Issues**

#### **VMs Won't Start**
```bash
# Check VirtualBox is running
sudo systemctl status vboxdrv

# Check available resources
free -h
df -h
```

#### **Cluster Not Ready**
```bash
# Check node status
vagrant ssh control-plane -c "kubectl get nodes"

# Check pod status
vagrant ssh control-plane -c "kubectl get pods --all-namespaces"

# Check logs
vagrant ssh control-plane -c "kubectl logs -n kube-system <pod-name>"
```

#### **Network Issues**
```bash
# Check network connectivity
vagrant ssh control-plane -c "ping 192.168.56.11"
vagrant ssh control-plane -c "ping 192.168.56.12"
```

### **Reset Cluster**
```bash
# Destroy and recreate
vagrant destroy -f
vagrant up
```

## 📚 **Documentation**

- **Setup Guide**: This README
- **Troubleshooting**: See troubleshooting section above
- **Examples**: Bring your own manifests or Helm charts

## 🧰 Notes

- Synced folders are disabled for performance and isolation. All provisioning is done over SSH via Ansible.
- External variables are defined in `vagrant-vars.rb` and loaded by `Vagrantfile`.
- You can re-run provisioning at any time with:
  - `./scripts/provision.sh` (runs Ansible against all nodes)

## 🤝 **Contributing**

This project is designed for:
- **Learning Kubernetes** locally
- **Development and testing**
- **Experimenting with configurations**
- **Understanding cluster components**

## 📄 **License**

This project is licensed under the MIT License.
