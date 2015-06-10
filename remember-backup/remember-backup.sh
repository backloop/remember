#!/bin/bash

# store the current time in a friendly format this will be used to modify
# the access time of the REMEMBER_DEST directory when rsync has completed.
REMEMBER_START_TIME="$(date +%Y%m%d%H%M)"

echo -n "Reading configuration..."
# do not use readlink -f/-m because this will canonicalize paths that may not
# be accessible, e.g. due to missing permissions.
. $(dirname $0)/remember-backup.conf 2>/dev/null
if [ ! $? = 0 ]; then
    echo " FAIL"
    echo "Could not load configuration file. Abort."
    exit 1
fi
echo " OK"

# set default values
: ${REMEMBER_ONSITE_REVERSE_PORT:=2222}
: ${REMEMBER_OFFSITE_USER:=root}

# ConnectTimeout after 10 seconds when the target is down or really unreachable,
# not when it refuses the connection.
REMOTE_CMD="ssh -o ConnectTimeout=10 -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost"

function exit_fail() {
    echo "FAIL. Abort."
    exit 1
}

echo -n "Check that the reverse SSH tunnel exis_fail... "
if ! $REMOTE_CMD "exit"; then
    exit_fail
fi
echo "OK"

echo -n "Check local directory ($REMEMBER_SOURCE)... "
if [ ! -d $REMEMBER_SOURCE ]; then
    exit_fail
fi
echo "OK"

if [ -n "$REMEMBER_ECRYPTFS_ALIAS" ]; then

    echo -n "Check the eCryptfs passphrase... "
    if [ -z "$REMEMBER_ECRYPTFS_PASSPHRASE" ]; then
        exit_fail
    fi
    echo "OK"
    
    echo -n "Adding the passphrase to the remote key ring... "
    output=$($REMOTE_CMD "ecryptfs-add-passphrase --fnek <<< $REMEMBER_ECRYPTFS_PASSPHRASE")
    count=$(echo $output | grep -v 'Inserted auth tok' | wc -l) 
    if (( $count != 0 )); then
        echo $output
        exit_fail
    fi
    echo "OK"

    echo -n "Decrypting remote directory... "
    if ! $REMOTE_CMD "mount.ecryptfs_private $REMEMBER_ECRYPTFS_ALIAS"; then
        exit_fail
    fi
    echo "OK"
fi

echo -n "Check remote base directory ($REMEMBER_BASEPATH)... "
if $REMOTE_CMD "[ ! -d $REMEMBER_BASEPATH ]"; then
    exit_fail
fi
echo "OK"

REMEMBER_DEST=$REMEMBER_BASEPATH/current
echo -n "Check remote destination directory ($REMEMBER_DEST)... "
# "current" directory should not exist after a successful backup.
if $REMOTE_CMD "[ -d $REMEMBER_DEST ]"; then
    if ! $REMOTE_CMD "rm -r $REMEMBER_DEST"; then
        exit_fail
    fi
fi
echo "OK"

REMEMBER_LINKDEST=$REMEMBER_BASEPATH/previous
echo -n "Check remote destination directory ($REMEMBER_LINKDEST)... "
# "previous" directory contains last successful backup, if it does not exist
# then create an empty directory for rsync to diff against
if $REMOTE_CMD "[ ! -d $REMEMBER_LINKDEST ]"; then
    if ! $REMOTE_CMD "mkdir $REMEMBER_LINKDEST"; then
        exit_fail
    fi
fi
echo "OK"

echo -n "Checking remote rsync permissions... "
REMEMBER_RSYNC_PERMISSION=/etc/sudoers.d/01_remember-backup
if $REMOTE_CMD "[ ! -e $REMEMBER_RSYNC_PERMISSION ]"; then
    echo "Missing rsync permission file $REMEMBER_RSYNC_PERMISSION."
    exit_fail
fi
echo "OK"

REMEMBER_RSYNC_TMP=$REMEMBER_BASEPATH/rsync_tmp
echo -n "Check remote rsync temporary directory ($REMEMBER_RSYNC_TMP)... "
# The temp directory should not exist after a successful backup.
# if it exists then it is stale and should be removed to avoid
# confusing rsync with old content
if $REMOTE_CMD "[ -d $REMEMBER_RSYNC_TMP ]"; then
    if ! $REMOTE_CMD "rm -r $REMEMBER_RSYNC_TMP"; then
        exit_fail
    fi
fi
echo "OK"

echo -n "Run rsync to a temporary directory... "
#           --progress \
#           --stats \
if ! rsync --archive \
           --rsh="ssh -p$REMEMBER_ONSITE_REVERSE_PORT" \
           --rsync-path="sudo rsync" \
           --delete-before --delete-excluded --prune-empty-dirs \
           --link-dest=$REMEMBER_LINKDEST \
           $REMEMBER_SOURCE $REMEMBER_OFFSITE_USER@localhost:$REMEMBER_RSYNC_TMP; then
    exit_fail
fi
echo "OK"

# only the file owner can change mtime on files so rsync syncs to a tmp directory # and then were hardlinking all contents to a new directory that the offsite user # owns. Now we can set the start time of the backup as the modify time.
echo -n "Copy rsync temp directory to \"$REMEMBER_DEST\"... "
if ! $REMOTE_CMD "cp -r -l -p $REMEMBER_RSYNC_TMP $REMEMBER_DEST"; then
    exit_fail
fi
echo "OK"

echo -n "Delete the rsync temp directory... "
if ! $REMOTE_CMD "rm -r $REMEMBER_RSYNC_TMP"; then
    exit_fail
fi
echo "OK"

echo -n "Modify times on remote directory \"$REMEMBER_DEST\"... "
if ! $REMOTE_CMD "touch -t $REMEMBER_START_TIME $REMEMBER_DEST"; then
    exit_fail
fi
echo "OK"

echo -n "Copy rotation script... "
REMEMBER_ROTATE=$REMEMBER_BASEPATH/remember-rotate.sh
if ! scp -q -P$REMEMBER_ONSITE_REVERSE_PORT remember-rotate.sh $REMEMBER_OFFSITE_USER@localhost:$REMEMBER_ROTATE; then
    exit_fail
fi
echo "OK"

echo -n "Perform rotation... "
REMEMBER_MAX_ROTATE="$REMEMBER_MAX_DAILY,$REMEMBER_MAX_WEEKLY,$REMEMBER_MAX_MONTHLY,$REMEMBER_MAX_YEARLY"
if ! $REMOTE_CMD "$REMEMBER_ROTATE $REMEMBER_BASEPATH $REMEMBER_DEST $REMEMBER_MAX_ROTATE"; then
    exit_fail
fi
echo "OK"

echo -n "Remove rotation script... "
if ! $REMOTE_CMD "rm $REMEMBER_ROTATE"; then
    exit_fail
fi
echo "OK"

echo -n "Move $REMEMBER_DEST to $REMEMBER_LINKDEST... "
# Consider $REMEMBER_DEST as consumed. Move to $REMEMBER_LINKDEST so that
# e.g. hardlinking rsync backups have something to compare against.
if ! $REMOTE_CMD "rm -r $REMEMBER_LINKDEST"; then
    exit_fail
fi

if ! $REMOTE_CMD "mv $REMEMBER_DEST $REMEMBER_LINKDEST"; then
    exit_fail
fi
echo "OK"

echo -n "Total backup size: "
if ! $REMOTE_CMD "du -sh $REMEMBER_BASEPATH | cut -f 1"; then
    exit_fail
fi

echo -n "Total disk usage: "
if ! $REMOTE_CMD "df $REMEMBER_BASEPATH | tail -1 | sed 's/^.* \([0-9]*%\).*$/\1/g'"; then
    exit_fail
fi

if [ -n "$REMEMBER_ECRYPTFS_ALIAS" ]; then
    echo -n "Encrypting remote directory... "
    if ! $REMOTE_CMD "umount.ecryptfs_private $REMEMBER_ECRYPTFS_ALIAS"; then
        exit_fail
    fi
    echo "OK"
fi
