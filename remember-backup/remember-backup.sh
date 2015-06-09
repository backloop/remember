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

echo -n "Check that the reverse SSH tunnel exists"
if ! $REMOTE_CMD "exit"; then
    echo " FAIL"
    echo "Reverse SSH tunnel not active. Abort."
    exit 1
fi
echo " OK"

echo -n "Check local directory..."
if [ ! -d $REMEMBER_SOURCE ]; then
    echo " FAIL"
    echo "Missing local directory \"$REMEMBER_SOURCE\". Abort."
    exit 1
fi
echo " OK"

if [ -n "$REMEMBER_ECRYPTFS_ALIAS" ]; then
    echo -n "Decrypting remote directory..."

    if [ -z "$REMEMBER_ECRYPTFS_PASSPHRASE" ]; then
        echo " FAIL"
        echo "Empty eCryptfs passphrase. Abort."
        exit 1
    fi

    if ! $REMOTE_CMD "ecryptfs-add-passphrase --fnek <<< $REMEMBER_ECRYPTFS_PASSPHRASE"; then
        echo " FAIL"
        echo "Failed to add the passphrase to the remote key ring. Abort."
        exit 1
    fi

    if ! $REMOTE_CMD "mount.ecryptfs_private $REMEMBER_ECRYPTFS_ALIAS"; then
        echo " FAIL"
        echo "Failed to add the passphrase to the remote key ring. Abort."
        exit 1
    fi
    echo " OK"
fi

echo -n "Check remote base directory..."
if $REMOTE_CMD "[ ! -d $REMEMBER_BASEPATH ]"; then
    echo " FAIL"
    echo "Missing remote directory \"$REMEMBER_BASEPATH\". Abort."
    exit 1
fi
echo " OK"

echo -n "Check remote destination directory (current)..."
REMEMBER_DEST=$REMEMBER_BASEPATH/current
# "current" directory should not exist after a successful backup.
# if it exists then it is stale and should be removed to avoid
# confusing rsync with old content
if $REMOTE_CMD "[ -d $REMEMBER_DEST ]"; then
    if ! $REMOTE_CMD "rm -rf $REMEMBER_DEST"; then
        echo " FAIL"
        echo "Failed in removing stale remote directory \"$REMEMBER_DEST\". Abort."
        exit 1
    fi
fi
echo " OK"

echo -n "Check remote destination directory (previous)..."
REMEMBER_LINKDEST=$REMEMBER_BASEPATH/previous
# "previous" directory contains last successful backup, if it does not exist
# then create an empty directory for rsync to diff against
if $REMOTE_CMD "[ ! -d $REMEMBER_LINKDEST ]"; then
    if ! $REMOTE_CMD "mkdir $REMEMBER_LINKDEST"; then
        echo " FAIL"
        echo "Creating remote directory \"$REMEMBER_LINKDEST\" failed. Abort."
        exit 1
    fi
fi
echo " OK"

echo -n "Checking remote rsync permissions..."
REMEMBER_RSYNC_PERMISSION=/etc/sudoers.d/01_remember-backup
if $REMOTE_CMD "[ ! -e $REMEMBER_RSYNC_PERMISSION ]"; then
    echo " FAIL"
    echo "Missing rsync permission file $REMEMBER_RSYNC_PERMISSION. Manually copy to remote machine. Abort."
    exit 1
fi
echo " OK"

echo -n "Running rsync..."
REMEMBER_RSYNC_TMP=$REMEMBER_BASEPATH/rsync_tmp
#           --progress \
#           --stats \
if ! rsync --archive \
           --rsh="ssh -p$REMEMBER_ONSITE_REVERSE_PORT" \
           --rsync-path="sudo rsync" \
           --delete-before --delete-excluded --prune-empty-dirs \
           --link-dest=$REMEMBER_LINKDEST \
           $REMEMBER_SOURCE $REMEMBER_OFFSITE_USER@localhost:$REMEMBER_RSYNC_TMP; then
    echo " FAIL"
    exit 1
fi

# only the file owner can change mtime on files so rsync syncs to a tmp directory # and then were hardlinking all contents to a new directory that the offsite user # owns. Now we can set the start time of the backup as the modify time.
if ! $REMOTE_CMD "cp -r -l -p $REMEMBER_RSYNC_TMP $REMEMBER_DEST"; then
    echo " FAIL"
    echo "Moving remote directory to \"$REMEMBER_DEST\" failed. Abort."
    exit 1
fi

if ! $REMOTE_CMD "rm -rf $REMEMBER_RSYNC_TMP"; then
    echo " FAIL"
    echo "Deleting the rsync tmp destination \"$REMEMBER_RSYNC_TMP\" failed. Abort."
    exit 1
fi

if ! $REMOTE_CMD "touch -t $REMEMBER_START_TIME $REMEMBER_DEST"; then
    echo " FAIL"
    echo "Modifying access time on remote directory \"$REMEMBER_DEST\" failed. Abort."
    exit 1
fi
echo " OK"

echo -n "Copy rotation script..."
REMEMBER_ROTATE=$REMEMBER_BASEPATH/remember-rotate.sh
if ! scp -q -P$REMEMBER_ONSITE_REVERSE_PORT remember-rotate.sh $REMEMBER_OFFSITE_USER@localhost:$REMEMBER_ROTATE; then
    echo " FAIL"
    exit 1
fi
echo " OK"

REMEMBER_MAX_ROTATE="$REMEMBER_MAX_DAILY,$REMEMBER_MAX_WEEKLY,$REMEMBER_MAX_MONTHLY,$REMEMBER_MAX_YEARLY"
if ! $REMOTE_CMD "$REMEMBER_ROTATE $REMEMBER_BASEPATH $REMEMBER_DEST $REMEMBER_MAX_ROTATE"; then
    echo " FAIL"
    echo "Failed execution of $REMEMBER_ROTATE. Abort."
    exit 1
fi

echo -n "Cleaning up..."
if ! $REMOTE_CMD "rm $REMEMBER_ROTATE"; then
    echo " FAIL"
    echo "Failed removal of $REMEMBER_ROTATE. Abort."
    exit 1
fi

# Consider $REMEMBER_DEST as consumed. Move to $REMEMBER_LINKDEST so that 
# e.g. hardlinking rsync backups have something to compare against.
if ! $REMOTE_CMD "rm -rf $REMEMBER_LINKDEST"; then
    echo " FAIL"
    echo "Failed while removing $REMEMBER_LINKDEST. Abort."
    exit 1
fi

if ! $REMOTE_CMD "mv $REMEMBER_DEST $REMEMBER_LINKDEST"; then
    echo " FAIL"
    echo "Failed while moving $REMEMBER_DEST. Abort."
    exit 1
fi
echo " OK"

echo -n "Total backup size: "
if ! $REMOTE_CMD "du -sh $REMEMBER_BASEPATH | cut -f 1"; then
    echo " FAIL"
    echo "Failed while examining total backup size. Abort."
    exit 1
fi

echo -n "Total disk usage: "
if ! $REMOTE_CMD "df $REMEMBER_BASEPATH | tail -1 | sed 's/^.* \([0-9]*%\).*$/\1/g'"; then
    echo " FAIL"
    echo "Failed while examining total disk usage. Abort."
    exit 1
fi

if [ -n "$REMEMBER_ECRYPTFS_ALIAS" ]; then
    echo -n "Encrypting remote directory..."
    if ! $REMOTE_CMD "umount.ecryptfs_private $REMEMBER_ECRYPTFS_ALIAS"; then
        echo " FAIL"
        echo "ENCRYPTION FAIL! Remote directory is still decrypted. Abort."
        exit 1
    fi
    echo " OK"
fi
