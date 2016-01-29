#!/bin/bash

# Perform a few steps first
export PATH=$PATH:/opt/puppet/bin
/opt/puppet/bin/puppet module install zack/r10k
/opt/puppet/bin/puppet module install hunner/hiera
/sbin/service iptables stop
/sbin/chkconfig iptables off

# Place the r10k configuration file
cat > /var/tmp/configure_r10k.pp << 'EOF'
class { 'r10k':
  version           => '2.1.1',
  sources           => {
    'puppet' => {
      'remote'  => 'https://github.com/cvquesty/control_repo.git',
      'basedir' => "${::settings::confdir}/environments",
      'prefix'  => false,
    }
  },
  manage_modulepath => false,
}
EOF

# Place the directory environments config file
cat > /var/tmp/configure_directory_environments.pp << 'EOF'
######                           ######
##  Configure Directory Environments ##
######                           ######

##  This manifest requires the puppetlabs/inifile module and will attempt to
##  configure puppet.conf according to the blog post on using R10k and
##  directory environments.  Beware!

# Default for ini_setting resources:
Ini_setting {
  ensure => present,
  path   => "${::settings::confdir}/puppet.conf",
}

ini_setting { 'Configure environmentpath':
  section => 'main',
  setting => 'environmentpath',
  value   => '$confdir/environments',
}

ini_setting { 'Configure basemodulepath':
  section => 'main',
  setting => 'basemodulepath',
  value   => '$confdir/modules:/opt/puppet/share/puppet/modules',
}
EOF

# Now configure Hiera
cat > /var/tmp/configure_hiera.pp << 'EOF'
class { 'hiera':
  hiera_yaml => '/etc/puppetlabs/puppet/hiera.yaml',
  hierarchy  => [
    'nodes/%{clientcert}',
    '%{environment}',
    'common',
  ],
  logger     => 'console',
  datadir    => '/etc/puppetlabs/puppet/environments/%{environment}/hieradata'
}
EOF

# Now, apply your new configuration
/opt/puppet/bin/puppet apply /var/tmp/configure_r10k.pp

# Then configure directory environments
/opt/puppet/bin/puppet apply /var/tmp/configure_directory_environments.pp

# Then configure Hiera
/opt/puppet/bin/puppet apply /var/tmp/configure_hiera.pp

# Do the first deployment run
/opt/puppet/bin/r10k deploy environment -pv

# Restart Puppet to pick up the new hiera.yaml
/sbin/service pe-puppet restart
/sbin/service pe-httpd restart
