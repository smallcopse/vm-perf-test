# -*- mode: ruby -*-
# vi: set ft=ruby :

def setup_vbguest(node, vbguest_vars)
  if vbguest_vars.has_key? 'installer' then
    node.vbguest.installer = vbguest_vars['installer']
  end
  if vbguest_vars.has_key? 'installer_options' then
    node.vbguest.installer_options = vbguest_vars['installer_options']
  end
end

