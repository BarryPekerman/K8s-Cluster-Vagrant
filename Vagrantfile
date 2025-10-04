# Vagrantfile

# ===================================================================
# Configuration Variables
# ===================================================================
$worker_nodes_count = 2
$memory_per_node = 2048
$cpus_per_node = 2
$private_network_ip_prefix = "192.168.56."

# ===================================================================
# Vagrant Configuration
# ===================================================================
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # --- Control Plane Node ---
  config.vm.define "control-plane" do |control|
    control.vm.hostname = "control-plane"
    control.vm.network "private_network", ip: "#{$private_network_ip_prefix}10"
    
    control.vm.provider "virtualbox" do |vb|
      vb.memory = $memory_per_node
      vb.cpus = $cpus_per_node
      vb.name = "k8s-control-plane"
    end
  end

  # --- Worker Nodes ---
  (1..$worker_nodes_count).each do |i|
    config.vm.define "worker-#{i}" do |worker|
      worker.vm.hostname = "worker-#{i}"
      worker.vm.network "private_network", ip: "#{$private_network_ip_prefix}#{10 + i}"
      
      worker.vm.provider "virtualbox" do |vb|
        vb.memory = $memory_per_node
        vb.cpus = $cpus_per_node
        vb.name = "k8s-worker-#{i}"
      end
    end
  end

  # --- Ansible Provisioner ---
  # This is the single entry point for all software configuration.
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "ansible/playbook.yml"
    ansible.inventory_path = "ansible/inventory"
  end
end
