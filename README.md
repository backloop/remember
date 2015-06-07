**WORK IN PROGRESS - HEAD IN NOT FUNCTIONAL**

# remember
Remote backup tool based on standard tools, with automatic rotation and minimal offsite machine configuration 

## remember-tunnel
The tool is a daemon executed on the offsite machine and sets up a persistent reverse SSH tunnel to the onsite machine. The underlying concept is that the offsite LAN configuration does not need to be changed, only onsite LAN needs configuring. Also the offsite machine's public domain name or IP address does not need to be known in beforehand. Only onsite machine's public domain name or IP address needs to be known (to initially set up the SSH tunnel).

Essentially this sets up a "call home" feature.

#### Example
The offsite machine is an offsite backup server located somewhere far away and the onsite machine is a file server on your home or office LAN.

#### Pre-requisites
* The onsite LAN must allow incoming SSH connections from the offsite machine to the onsite machine

#### Installation on onsite machine
Install the ssh daemon
```
# apt-get install ssh
```
Create a non-priviledged user
```
# adduser your-onsite-username
```

#### Installation on offsite machine
Install a ssh session management daemon
```
# apt-get install autossh
```
Create a non-priviledged user
```
# adduser your-offsite-username
# su your-offsite-username
$ ssh-keygen
$ exit
```
Configure unattended login to onsite machine (copies ssh keys and forces a known_hosts file update)
```
# su your-offsite-username
$ ssh-copy-id your-onsite-username@your-onsite-machine-hostname
$ exit
```
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

#### General Assumptions
1. Onsite firewall and router are owned by the admin configuring this daemon.
2. Onsite firewall can be configured to support incoming SSH connections to onsite machine. 
3. Offsite firewall and router are owned by someone else and cannot be configured.
4. Offsite firewall supports outgoing SSH connections from offsite machine. This holds true for most default configurations of consumer firewall/router devices.

## remember-backup
With the remember-tunnel active it is possible to use several existing backup tools through the SSH tunnel. This script package is describes the use of remember-backup.sh for backup. 
* eCryptfs is used for securing the offsite content.
* Rsync is used with hard-links to create backups thate are full, browsable with minimal bandwidth usage.
* Custom configurable backup rotation.
* ACL (Access Control List) is used to limit the need for elevating permissions of the offiste user

#### Installation on offsite machine
Enable rsync to run with elevated permissions without asking for passwords
```
# su your-offsite-username
$ cp remember-backup/01_rememeber-backup.template /etc/suders.d/01_remember-backup
$ sed -i "s/REMEMBER_OFFSITE_USER/your-offsite-username/" /etc/suders.d/01_remember-backup
$ exit
```
Create an eCryptfs storage that is compatible with mount.ecryptfs_private. Follow the instructions at the [eCryptfs wiki 'With eCryptfs-utils'](https://wiki.archlinux.org/index.php/ECryptfs#With_ecryptfs-utils)

Use ACL (Access Control List) to allow the offsite user to delete contents within the eCryptfs storage without needing elevated permissions. The reason is that the storage will most likely contain files with different permissions and ownwers. The alternative would be to add the "rm" command to the sudoers configuration file but it would be impossible to restrict the pemissions to the eCryptfs storage alone.

The first part is to [enable ACL](https://wiki.archlinux.org/index.php/Access_Control_Lists#Enabling_ACL) in the underlying filesystem. This can be done in the fstab or on the default mount options for the drive.

The second part is to set the default ACL permissions for new directories/files in the eCryptfs storage. This will allow your offsite user to delete any of contents in the eCryptfs storage irrespective of the original Linux permissions of the backup files.
CAVEAT: When restoring a backup the ACL permisssions must be manually cleaned from the permissions that are added below.  
```
# setfacl -dm "u:your-offsite-username:rwX" /path/to/the/encrypted-ecryptfs-directory
```

#### Installation on onsite machine
Create ssh keys for your non-priviledged user
```
# su your-onsite-username
$ ssh-keygen
$ exit
```
Configure unattended login to offsite machine through the reverse SSH tunnel (copies ssh keys and forces a known_hosts file update)
```
# su your-onsite-username
$ ssh-copy-id -p 2222 your-offsite-username@localhost
$ exit
```
Make changes to fit your configuration
```
# vi remember-backup/remember-backup.conf
```
Create a cron entry for your onsite user
```
# crontab -u your-onsite-username -e
```
Add the following to execute the backup every day.
```
00 01 * * * /path-to-remember-backup/remember-backup.sh
```

## remember-restore
With the remember-tunnel active it is possible to use several exisiting restore tools through the SSH tunnel. This script package is describes the use of either rsync of sshfs for restore.

#### Assumption
Restoring files on the onsite machine is performed by an admin with root priviledges. The setup is not intended for multiple end users restoring their own files.

#### Pre-requisites
TODO

#### Example usage from onsite machine
TODO
