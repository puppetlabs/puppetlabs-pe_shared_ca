# Shared Certificates for Puppet Enterprise Masters
#
# This class is intended to be run in a oneoff scenario to aid in the
# bootstrapping of a shared ca environment.  It is not meant to be
# permanantly installed as part of a maintained Puppet environment.
#
# Resources managed on a Puppet Console Master:
#
# Resources managed on a Puppet Master without Console:
#
# == Parameters
#
class pe_shared_ca(
  $ca_folder_source       = "puppet:///modules/${module_name}/ca",
  $internal_folder_source = "puppet:///modules/${module_name}/pe-internal",
  $mco_credentials_source = "puppet:///modules/${module_name}/credentials",
  $shared_ca_server
) {
  validate_bool($shared_ca_server)

  # Setup variables to represent various files this class will manipulate
  $ca_files_to_purge = [
    '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
    "/etc/puppetlabs/puppet/ssl/certs/${::clientcert}.pem",
    "/etc/puppetlabs/puppet/ssl/private_keys/${::clientcert}.pem",
    "/etc/puppetlabs/puppet/ssl/public_keys/${::clientcert}.pem",
    '/etc/puppetlabs/puppet/ssl/crl.pem',
  ]
  # $ca_files_to_copy was added to document which files needed to be maintained
  # by this module on the non-shared_ca_server nodes
  $ca_files_to_copy = [
    '/etc/puppetlabs/puppet/ssl/ca/ca_crl.pem',
    '/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem',
    '/etc/puppetlabs/puppet/ssl/ca/ca_key.pem',
    '/etc/puppetlabs/puppet/ssl/ca/ca_pub.pem',
    '/etc/puppetlabs/puppet/ssl/certs/pe-internal-mcollective-servers.pem',
    '/etc/puppetlabs/puppet/ssl/certs/pe-internal-peadmin-mcollective-client.pem',
    '/etc/puppetlabs/puppet/ssl/private_keys/pe-internal-mcollective-servers.pem',
    '/etc/puppetlabs/puppet/ssl/private_keys/pe-internal-peadmin-mcollective-client.pem',
    '/etc/puppetlabs/puppet/ssl/public_keys/pe-internal-mcollective-servers.pem',
    '/etc/puppetlabs/puppet/ssl/public_keys/pe-internal-peadmin-mcollective-client.pem',
    '/etc/puppetlabs/puppet/ssl/public_keys/pe-internal-puppet-console-mcollective-client.pem',
  ]
  $mco_files_to_purge = [
    '/etc/puppetlabs/mcollective/ssl',
    '/etc/puppetlabs/activemq/broker.ks',
    '/etc/puppetlabs/activemq/broker.p12',
    '/etc/puppetlabs/activemq/broker.pem',
    '/etc/puppetlabs/activemq/broker.ts',
  ]
  # Puppet core ships a newer version of the create_resources function
  # than what shipped in the pe_accounts module with PE
  # Cody's pe_mcollective branch needs the newer function
  $old_function_to_purge = '/opt/puppet/share/puppet/modules/pe_accounts/lib/puppet/parser/functions/create_resources.rb'
  $mco_credentials_file = '/etc/puppetlabs/mcollective/credentials'

  if $shared_ca_server {
    $files_to_purge = [ $mco_files_to_purge, $old_function_to_purge ]
  } else {
    $files_to_purge = [
      $ca_files_to_purge,
      $mco_files_to_purge,
      $old_function_to_purge,
    ]
    file { 'replace_ca_dir':
      ensure  => directory,
      path    => '/etc/puppetlabs/puppet/ssl/ca',
      source  => $ca_folder_source,
      recurse => true,
      purge   => true,
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
      require => File[$files_to_purge],
    }
    file { 'replace_mco_credentials':
      ensure => file,
      path   => '/etc/puppetlabs/mcollective/credentials',
      source => $mco_credentials_source,
      owner  => 'pe-puppet',
      group  => 'pe-puppet',
      mode   => '0600',
      require => File[$files_to_purge],
    }
    file { 'replace_internal_certs':
      ensure  => directory,
      path    => '/etc/puppetlabs/puppet/ssl/certs',
      source  => "${internal_folder_source}/private_keys",
      recurse => true,
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
    }
    file { 'replace_internal_private_keys':
      ensure  => directory,
      path    => '/etc/puppetlabs/puppet/ssl/private_keys',
      source  => "${internal_folder_source}/private_keys",
      recurse => true,
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
    }
    file { 'replace_internal_public_keys':
      ensure  => directory,
      path    => '/etc/puppetlabs/puppet/ssl/public_keys',
      source  => "${internal_folder_source}/public_keys",
      recurse => true,
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
    }
  }
  service { [
    'pe-puppet',
    'pe-httpd',
    'pe-mcollective',
    'pe-activemq'
  ]:
    ensure  => 'stopped',
    before  => File[$files_to_purge],
  }
  file { $files_to_purge:
    ensure  => absent,
    recurse => true,
    force   => true,
  }
}
