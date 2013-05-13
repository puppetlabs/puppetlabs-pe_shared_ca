Module: pe_shared_ca
=================

# THIS DOCUMENTATION IS OUT OF DATE -- So someone needs to update it

Module to aid in the creation of a shared CA Puppet Infrastructure

Goal or Use Case
----------------
Have a central CA/Console host on a network that any number of masters can submit inventory data to (over REST). These masters should be able to sign their own agents, so agents don't need connectivity to the console host, amongst other potential reasons.

Also, each master's ActiveMQ server should participate in a shared broker mesh, including the console host, so orchestration can be done throughout the environment, including console live management.


Concepts
--------
In order to satisfy these goals, the CA living on the console host will be replicated out to each Puppet Master wishing to participate in the shared environment. Each of those masters CA (created by the PE installer script) will be replaced with the CA of the console host. The masters certificates (again, created at install) also need destroyed and re-signed by the shared CA.

ActiveMQ and MCollective will participate in a similar fashion but Puppet and the `pe_mcollective` module will handle certificate management here. Because we want the broker mesh to be automatically managed by Puppet, we'll be using a slightly modified `pe_mcollective` module than what ships with PE. It includes code to manage the brokers, functionality intended for a future release.

The `pe_shared_ca` module aids in some of these tasks, mostly file copies & deletions.


Pre-Requisites
--------------

1. Install PE 2.5 onto a host with the console, master, & agent roles selected (you'll get CA certs for free). Referred to as the "shared CA server" host.
1. Install PE 2.5 on any number of hosts with just the master & agent roles (no console). Referred to as Master hosts (non-shared-ca servers)
1. Copy the following data from the shared CA server into this modules' specified directories if it is not already done:
    - CA directory: `/etc/puppetlabs/puppet/ssl/ca/` to `$module_name/files/ca/`
    - MCollective Credentials file: `/etc/puppetlabs/mcollective/credentials` to `$module_name/files/credentials`
    - MC server certs:
        - `/etc/puppetlabs/puppet/ssl/certs/pe-internal-mcollective-servers.pem` to `$module_name/files/pe-internal/certs`
        - `/etc/puppetlabs/puppet/ssl/private_keys/pe-internal-mcollective-servers.pem` `$module_name/files/pe-internal/private_keys`
        - `/etc/puppetlabs/puppet/ssl/public_keys/pe-internal-mcollective-servers.pem` `$module_name/files/pe-internal/public_keys`
    - `peadmin` user certs:
        - `/etc/puppetlabs/puppet/ssl/certs/pe-internal-peadmin-mcollective-client.pem` `$module_name/files/pe-internal/certs`
        - `/etc/puppetlabs/puppet/ssl/private_keys/pe-internal-peadmin-mcollective-client.pem` `$module_name/files/pe-internal/private_keys`
        - `/etc/puppetlabs/puppet/ssl/public_keys/pe-internal-peadmin-mcollective-client.pem` `$module_name/files/pe-internal/public_keys`
    - Console Live Management public key: `/etc/puppetlabs/puppet/ssl/public_keys/pe-internal-puppet-console-mcollective-client.pem` `$module_name/files/pe-internal/public_keys`
1. You'll also need to use a modified `pe_mcollective` module until a compatible version makes it way into a PE 2.5.x release.
    - `pe_mcollective` -- Module that handles ActiveMQ & MCollective (source is the [private repo branch](https://github.com/ody/puppetlabs-pe_mcollective/tree/ticket/master/xxxx_puppetca_support))
1. If you want master hosts to send inventory data back to the shared CA (console) host, you'll need to modify `/etc/puppetlabs/puppet/auth.conf` on the shared CA host and add an entry for each master machine to the following section of that file.

```
path /facts
auth yes
method save
allow master.cert.name
```

Usage
=====

The `pe_shared_class` must be declared with the `shared_ca_server` parameter which accepts a boolean `true` or `false` depending on what system you're running on.

Example class declarations are available in the usage folder for your use.

Preparing the Shared CA
-----------------------
Once those prerequisites are met, you should run puppet apply against this module on each of your systems to prepare the hosts. For example, if you place this module into /root on your target systems during the bootstrap process and are running on the CA host:

* `puppet apply --modulepath=/root:/opt/puppet/share/puppet/modules --certname=your_machines_certname /root/pe_shared_ca/usage/is_ca_server.pp`
* `--modulepath` needs to include the directory where the stdlib module lives. The example includes the folder stdlib lives in PE 2.5.0. `--certname` is required if your installed certificate name differs from your hostname.
* `is_ca_server.pp` contains the class declaration needed to prep your shared CA server.

```
class { 'pe_shared_ca':
  shared_ca_server => true,
}
```

Declaring the `pe_shared_ca` class with `shared_ca_server => true` will:

* Stop services: `pe-puppet`, `pe-httpd`, `pe-mcollective` & `pe-activemq`
* Copy the `pe_mcollective` module to `/etc/puppetlabs/puppet/modules`
* Purge MCollective Certificates
* Purge an old `create_resources` function that shipped with PE 2.5 by accident.

Declaring the `pe_shared_ca` class with `shared_ca_server => false` will:

* Do the same as above, plus:
* Purge the hosts entire `$cadir` & replace it the CA folder you created during the pre-requisites.
* Replace `/etc/puppetlabs/mcollective/credentials` with one from your Console host
* Purge the Master host certificate/key pair that were created during install.


Starting the Modified Host
-----------------------------
Once the module has done it's business, you have two paths to continue.


1. On the shared CA host:
    1. Start the `pe-httpd` service.
    1. Run `puppet agent -t` which will now regenerate MCollective certificates and restart pe-mcollective and pe-activemq.
        - If you're not autosigning certificates, you will need to sign the MCollective certificate. `Exec[check_for_signed_broker_cert]` will fail on your first Puppet run, indicating that the certificate has not been signed.
        - `puppet cert --list & puppet cert --sign $certname.pe-internal-broker`
        - Run `puppet agent -t` again to finish the process.
    1. Optionally turn back on the pe-puppet service.
1. On a Master Host:
    1. Start a Puppet Master manually, as it needs to generate and sign a new cert from your shared CA.
        -  `puppet master --no-daemonize --debug`
        -  Once that's done (you should see it startup successfully), you can control+C the process.
    1. Start the `pe-httpd` service.
    1. Run `puppet agent -t` which should now regenerate MCollective certificates and restart `pe-mcollective` and `pe-activemq`.
        - If you're not autosigning certificates, you will need to sign the MCollective certificate. `Exec[check_for_signed_broker_cert]` will fail on your first Puppet run, indicating that the certificate has not been signed.
        - `puppet cert --list & puppet cert --sign $certname.pe-internal-broker`
        - Run `puppet agent -t` again to finish the process.
    ctive certificate. `puppet cert --list` & `puppet cert --sign` as appropriate.
    1. Optionally restart the `pe-puppet` service.

TO-DO: 

* Document ActiveMQ scaling. Most content is already in the `pe_mcollective` module, really just need the `activemq_brokers=broker1,broker2` variable behavior.
* See tickets for additional issues.
