# Vagrantfile

# Load external variables
load 'vagrant-vars.rb'

# ===================================================================
# Vagrant Configuration
# ===================================================================
Vagrant.configure("2") do |config|
  config.vm.box = VM_BOX
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # --- Control Plane Node ---
  config.vm.define "control-plane" do |control|
    control.vm.hostname = "control-plane"
    control.vm.network "private_network", ip: "#{PRIVATE_NETWORK_IP_PREFIX}10"
    
    control.vm.provider "virtualbox" do |vb|
      vb.memory = MEMORY_PER_NODE
      vb.cpus = CPUS_PER_NODE
      vb.name = "k8s-control-plane"
    end
  end

  # --- Worker Nodes ---
  (1..WORKER_NODES_COUNT).each do |i|
    config.vm.define "worker-#{i}" do |worker|
      worker.vm.hostname = "worker-#{i}"
      worker.vm.network "private_network", ip: "#{PRIVATE_NETWORK_IP_PREFIX}#{10 + i}"
      
      worker.vm.provider "virtualbox" do |vb|
        vb.memory = MEMORY_PER_NODE
        vb.cpus = CPUS_PER_NODE
        vb.name = "k8s-worker-#{i}"
      end
    end
  end

  # --- Ansible Provisioner ---
  # This is the single entry point for all software configuration.
  # Only run on control-plane but target all hosts in inventory
  config.vm.define "control-plane" do |control|
    control.vm.provision "ansible" do |ansible|
      ansible.playbook = "ansible/playbook.yml"
      ansible.inventory_path = "ansible/inventory"
      ansible.limit = "all"
    end
  end
end
