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

#### Example usage from onsite machine
This example starts a ssh session from onsite machine through the reverse SSH tunnel to offsite machine. This command may force an update of the known_hosts file.
```
$ ssh -p 2222 your-offsite-username@localhost
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
Create a cron schedule for your onsite user
```
# crontab -u your-onsite-username -e
```
Add the following to execute the backup every day.
```
00 01 * * * /path-to-remember-backup/remember-backup.sh
```

#### Installation on offsite machine
Enable rsync to run with elevated priviledges without asking for passwords
```
# su your-offsite-username
$ cp remember-backup/01_rememeber-backup.template /etc/suders.d/01_remember-backup
$ sed -i "s/REMEMBER_OFFSITE_USER/your-offsite-username/" /etc/suders.d/01_remember-backup
$ exit
```
Create an eCryptfs storage that is compatible with mount.ecryptfs_private. Follow the instructions at the [eCryptfs wiki 'With eCryptfs-utils'](https://wiki.archlinux.org/index.php/ECryptfs#With_ecryptfs-utils)

## remember-restore
With the remember-tunnel active it is possible to use several exisiting restore tools through the SSH tunnel. This script package is describes the use of either rsync of sshfs for restore.

#### Assumption
Restoring files on the onsite machine is performed by an admin with root priviledges. The setup is not intended for multiple end users restoring their own files.

#### Pre-requisites
TODO

#### Example usage from onsite machine
TODO
