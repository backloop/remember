**WORK IN PROGRESS - HEAD IN NOT FUNCTIONAL**

# remember
Remote backup tool based on standard tools, with automatic rotation and minimal offsite machine configuration 

## remember-tunnel
The tool is a daemon executed on the offsite machine and sets up a persistent reverse SSH tunnel to the onsite machine. The underlying concept is that the offsite LAN configuration does not need to be changed, only onsite LAN needs configuring. Also the offsite machine's public domain name or IP address does not need to be known in beforehand. Only onsite machine's public domain name or IP address needs to be known (to initially set up the SSH tunnel).

Essentially this sets up a "call home" feature.

#### Example
The offsite machine is an offsite backup server located somewhere far away and the onsite machine is a file server on your home or office LAN.

#### Pre-requisites
* Offsite machine: autossh package must be installed
* Onsite LAN: Allow incoming SSH connections from offsite machine to onsite machine
* Automated login from the offsite machine to the onsite machine must be configured (public keys must be shared for the correct user on the offsite machine to the correct user on the onsite machine. Also, the known_hosts file on offsite machine must be updated with onsite machine's public credentials). The most straight forward method is to manually configure a normal ssh login from the offsite machine to the onsite machine that can be executed without user interaction.

#### Installation on offsite machine
Copy the necessary files
```
# cp remember-tunnel/etc/init.d/remember-tunnel  /etc/init.d/remember-tunnel
# cp remember-tunnel/etc/default/remember-tunnel /etc/default/remember-tunnel
```
Make changes to fit your configuration
```
# vi /etc/default/remember-tunnel
```
Register and start the daemon
```
# update-rc.d remember-tunnel defaults
# service remember-tunnel start
```

#### Example usage from onsite machine
This example starts a ssh session from onsite machine through the reverse SSH tunnel to offsite machine.
```
ssh -p 2222 offsite-username@localhost
```

#### Assumptions
1. Onsite firewall and router are owned by the admin configuring this daemon.
2. Onsite firewall can be configured to support incoming SSH connections to onsite machine. 
3. Offsite firewall and router are owned by someone else and cannot be configured.
4. Offsite firewall supports outgoing SSH connections from offsite machine. This holds true for most default configurations of consumer firewall/router devices.

## remember-backup
With the remember-tunnel active it is possible to use several existing backup tools through the SSH tunnel. This script package is describes the use of remember-backup.sh for backup. 
* eCryptfs is used for securing the offsite content.
* Rsync is used with hard-links to create a complete, browsable set of backups with minimal bandwidth usage.
* Custom configurable backup rotation is implemented.   

#### Pre-requisites
1. Automated login from the onsite machine to the offsite machine though the reverse SSH tunnel must be configured (public keys must be shared for the correct user on the onsite machine to the correct user on the offsite machine. Also, the known_hosts file on onsite machine must be updated). The most straight forward method is to manually configure a normal ssh login from the onsite machine to the offsite machine that can be executed without user interaction.
2. An eCryptfs storage must be created that is compatible with maount.ecryptfs_private (*.conf and *.sig files)

#### Installation on offsite machine
```
 $ cp 01_rememeber-backup.template /etc/suders.d/01_remember-backup
 $ sed -i "s/REMEMBER_OFFSITE_USER/your offsite username/" /etc/suders.d/01_remember-backup
```

#### Installation on onsite machine
TODO

#### Example usage from onsite machine
TODO cron example

## remember-restore
With the remember-tunnel active it is possible to use several exisiting restore tools through the SSH tunnel. This script package is describes the use of either rsync of sshfs for restore.

#### Assumption
Restoring files on the onsite machine is performed by an admin with root priviledges. The setup is not intended for multiple end users restoring their own files.

#### Pre-requisites
TODO

#### Example usage from onsite machine
TODO
