# remember
Remote backup tool based on standard tools, with automatic rotation and minimal offsite server configuration 

## remember-tunnel
The tool is executed on the OFFISTE_SERVER and sets up a persistent reverse SSH tunnel from ONSITE_SERVER to OFFSITE_SERVER. The underlying concept is that the OFFSITE_LAN configuration does not need to be changed, only ONSITE_LAN needs configuring. Also the OFFISTE_SERVER's public domain name or IP address needs not to be known in beforehand. Only ONSITE_SERVER's public domain name or IP address needs to be known (to initially set up the SSH tunnel).

Essentially this sets up a "call home" feature.

### Example
The OFFSITE_SERVER is an off-site backup server located somewhere far away and the ONSITE_SERVER is a file server on your home or office LAN.

### Pre-requisites
* autossh package must be installed
* Automated login from OFFSITE_SERVER to ONSITE_SERVER must be configured (public keys must be shared from OFFSITE_SERVER to ONSITE_SERVER and known_hosts file on OFFSITE_SERVER must be updated with ONSITE_SERVER's public credentials). The most straight forward method is to manually configure a normal ssh login from OFFSITE_SERVER to ONSITE_SERVER that can be executed without user interaction.  

### Installationon on OFFSITE_SERVER
```
cp remember-tunnel/etc/init.d/remember-tunnel  /etc/init.d/remember-tunnel
cp remember-tunnel/etc/default/remember-tunnel /etc/default/remember-tunnel
vi /etc/default/remember-tunnel <- make changes to fit your configuration
update-rc.d remember-tunnel defaults
service remember-tunnel start
```

### Example usage from ONSITE_SERVER
This example starts a ssh session from ONSITE_SERVER through the reverse SSH tunnel to OFFSITE_SERVER.
```
ssh -p 2222 <offsite username>@localhost
```

### Assumptions
1. On-site firewall and router are owned by the admin configuring this service.
2. On-site firewall can be configured to support incoming SSH connections to ONSITE_SERVER. 
3. Off-site firewall and router are owned by someone else and cannot be configured.
4. Off-site firewall supports outgoing SSH connections from OFFISTE_SERVER. This holds true for most default configurations of consumer firewall/router devices.

## remember-backup
With the remember-tunnel active it is possible to use several existing backup tools through the SSH tunnel. This script package is describes the use of remember-backup.sh for backup. The backup is based on rsync with hard-links to create complete, browsable backups with minimal bandwidth usage. Configurable backup rotation is also implemented.   

### Pre-requisites
* Automated login from ONSITE_SERVER to OFFSITE_SERVER though the reverse SSH tunnel must be configured (public keys must be shared from ONSITE_SERVER to OFFSITE_SERVER and known_hosts file on ONSITE_SERVER must be updated). The most straight forward method is to manually configure a normal ssh login from ONSITE_SERVER to OFFSITE_SERVER through the reverse SSH tunnel that can be executed without user interaction.
* On OFFSITE_SERVER
```
 $ cp 01_rememeber-backup.template /etc/suders.d/01_remember-backup
 $ sed -i "s/REMEMBER_OFFSITE_USER/your offsite username/" /etc/suders.d/01_remember-backup
```

TODO: Describe usage

## remember-restore
With the remember-tunnel active it is possible to use several exisiting restore tools through the SSH tunnel. This script package is describes the use of either rsync of sshfs for restore.

Assumption:
Restoring files on the LOCAL_SERVER is performed by an admin with root priviledges. The setup is not intended for multiple end users restoring their own files.

TODO: Describe usage
