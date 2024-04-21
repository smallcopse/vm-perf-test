# -*- mode: ruby -*-
# vi: set ft=ruby :

# ---------------------------
# add_network_interface
# ---------------------------
def add_network_interface(node, net_if, if_idx)
    # print if_idx
    # print net_if['type']
    case net_if['type']
    when 'internal' then
      # node.vm.network :private_network do |net|
      #   # if net_if.fetch('ip', 'dchp') == 'dhcp' then
      #   #   net.type = 'dhcp'
      #   # else
      #   #   net.ip = net_if['ip']
      #   # end
      #   net.ip = net_if['ip']
      #   if net_if.fetch('dchp', false) then
      #     net.type = 'dhcp'
      #     net.dhcp_lower = '172.17.177.10'
      #     net.dhcp_upper = '172.17.177.254'
      #     net.dhcp_ip = '172.17.177.1'
      #   end
      #   net.auto_config = net_if.fetch('auto_config', true)
      #   net.virtualbox__intnet = net_if['network_name']
      # end
      # node.vm.network 'private_network', ip: net_if['ip'], virtualbox__intnet: net_if['network_name']
      node.vm.network 'private_network',
        ip: net_if['ip'],
        type: net_if.fetch('dchp', ''),
        auto_config: net_if.fetch('auto_config', true),
        virtualbox__intnet: net_if['network_name']
    when 'private' then
      params = {ip: net_if['ip'], name: net_if['network_name']}
      if net_if.fetch('virtio', true) then
        params[:nic_type] = "virtio"
      end
      node.vm.network 'private_network', **params
    when 'dhcp' then
      node.vm.network 'private_network',
        # ip: net_if['ip'],
        name: net_if['network_name'],
        # auto_config: net_if.fetch('auto_config', true),
        adapter: 3,
        type: 'dhcp',
        # type: 'dhcp',
        dhcp_ip: net_if['dhcp_ip'],
        dhcp_lower: net_if['dhcp_lower'],
        dhcp_upper: net_if['dhcp_upper']
  
      if net_if.fetch('nat', false) then
        node.vm.provider 'virtualbox' do |vb|
          vb.customize ["modifyvm", :id, format('--nic%<x>d', x: idx + 1), "natnetwork"]
          vb.customize ["modifyvm", :id, format('--nat-network%<x>d', x: idx + 1), "NatNetwork"]
          if net_if.fetch('virtio', true) then
            vb.customize ["modifyvm", :id, format('--nictype%<x>d', x: if_idx), "virtio"]
          end
        end
      end
  
    # when 'bridge' then
    #   node.vm.network 'public_network', ip: net_if['ip']
    when 'nat' then
      # node.vm.network "private_network", :type => 'dhcp'
      node.vm.provider 'virtualbox' do |vb|
        vb.customize ["modifyvm", :id, format('--nic%<x>d', x: if_idx), "natnetwork"]
        vb.customize ["modifyvm", :id, format('--nat-network%<x>d', x: if_idx), net_if['network_name']]
        if net_if.fetch('virtio', true) then
          vb.customize ["modifyvm", :id, format('--nictype%<x>d', x: if_idx), "virtio"]
        end
      end
    when 'unassigned' then
      params = {auto_config: false}
      if net_if.fetch('virtio', true) then
        params[:nic_type] = "virtio"
      end
      node.vm.network 'public_network', **params
    when 'bridge' then
      params = {ip: net_if['ip'], type: net_if.fetch('dhcp', false)? 'dhcp' : 'static'}
      if net_if.fetch('virtio', true) then
        params[:nic_type] = "virtio"
      end
      node.vm.network 'public_network', **params
    else
      nil
    end
    # print format('|%<x>d|', x: if_idx)
    node.vm.provider 'virtualbox' do |vb|
      if net_if.fetch('promiscuous_mode', false) then
        vb.customize ["modifyvm", :id, format('--nicpromisc%<x>d', x: if_idx), "allow-all"]
      end
      # vb.customize ["modifyvm", :id, format('--nictype%<x>d', x: if_idx), "virtio"]
      vb.customize ["modifyvm", :id, format('--cableconnected%<x>d', x: if_idx), "on"]
    end
    # vb.customize ["modifyvm", :id, format('--cable-connected%<x>d', x: if_idx), "on"]
  # end
end

# ---------------------------
# create /etc/hosts content from inventory hosts
# ---------------------------
def generate_etc_hosts_content(inventory_hosts)
  etc_hosts_content = ''
  inventory_hosts.each do |host, hostvars|
    etc_hosts_content += hostvars['ip'] + ' ' + hostvars['hostname'] + '\n'
  end
  
  return etc_hosts_content
end

# ---------------------------
# add inventory hosts information to /etc/hosts
# ---------------------------
def add_inventory_hosts_to_etc_hosts(node, inventory_hosts)
  etc_hosts_content = generate_etc_hosts_content(inventory_hosts)
  etc_hosts_command = 'cat << "EOF" | sudo tee -a /etc/hosts\n' + etc_hosts_content + "EOF"
  node.vm.provision 'shell', privileged: false, inline: etc_hosts_command
end
