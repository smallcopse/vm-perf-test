# -*- mode: ruby -*-
# vi: set ft=ruby :

require './utils/network.rb'

def setup_vbguest(node, vbguest_vars)
  if vbguest_vars.has_key? 'installer' then
    node.vbguest.installer = vbguest_vars['installer']
  end
  if vbguest_vars.has_key? 'installer_options' then
    node.vbguest.installer_options = vbguest_vars['installer_options']
  end
end

def setup_node(node, hostvars)
  # set hostname as inventory hostname     
  node.vm.hostname = hostvars['hostname']
      
  # set vagrant box and box version
  node.vm.box = hostvars['box']
  node.vm.box_version = hostvars['box_version']
  
  # set disk size if specified
  if hostvars.has_key? 'disk_size' then
    node.disksize.size = hostvars['disk_size']
  end

  if hostvars.has_key?('remove_etc_hosts_localhost') and hostvars['remove_etc_hosts_localhost'] then
    node.vm.provision 'shell', privileged: true, inline: "sed -i -E 's/^127\..*"+hostvars['hostname']+".*/#&/g' /etc/hosts"
  end

  # vagrant-vbguest plugin settings
  if hostvars.has_key? 'vbguest' then
    setup_vbguest(node, hostvars['vbguest'])
  end

  # network interface settings
  hostvars.fetch('network_interfaces',[]).each_with_index do |net_if, idx|
    if_idx = idx + 2
    add_network_interface(node, net_if, if_idx)
  end

  # Virtualbox Settings
  node.vm.provider 'virtualbox' do |vb|
    vb.customize ["modifyvm", :id, "--firmware", "efi"]
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
    vb.customize ["modifyvm", :id, "--nictype1",  "virtio"]
    vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
    vb.customize ["modifyvm", :id, "--uartmode1", "file", File::NULL]
    vb.customize ['modifyvm', :id, '--cableconnected1', 'on']
    
    # sync host time
    vb.customize ["setextradata", :id, "VBoxInternal/Devices/VMMDev/0/Config/GetHostTimeDisabled", 0]
    
    # set display name in virtualbox
    vb.name = hostvars['hostname']
  
    # set CPUs
    if hostvars.has_key? 'cpus' then
      vb.cpus = hostvars['cpus']
    end
  
    # set memory size
    if hostvars.has_key? 'memory_size' then
      vb.memory = hostvars['memory_size']
    end
  end

  # # synced_folder
  # hostvars.fetch('synced_folder', []).each do |folder|
  #   node.vm.synced_folder File.join(VAGRANTFILE_DIR, folder['host']), folder['guest']
  # end

  # run shell provision
  hostvars.fetch('provision_pre_commands', []).each do |pre_command|
    node.vm.provision 'shell', privileged: false, inline: pre_command
  end

  # copy private key if 'copy_private_key: true' is specified
  if hostvars.fetch('copy_private_key', false) then
    node.vm.provision 'file', source: PRIVATE_KEY_PATH, destination: '~/.ssh/insecure_private_key'
    node.vm.provision 'shell', privileged: false, inline: <<-SHELL
      chmod 600 ~/.ssh/insecure_private_key
      cat ~/.ssh/insecure_private_key >> ~/.ssh/id_rsa
      chmod 600 ~/.ssh/id_rsa
    SHELL
  end

  # run ansible provision
  if hostvars.has_key? 'playbook' then
    node.vm.provision "ansible_local" do |ansible|
      ansible.playbook = hostvars['playbook']
      # ansible.install_mode = "pip"
      # ansible.version = "2.2.1.0"
    end
  end
end

