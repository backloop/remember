#!/bin/bash

echo -n "Reading configuration..."
. $(readlink -f $0 | xargs dirname)/remember-backup.conf 2>/dev/null
if [ ! $? = 0 ]; then
    echo " FAIL"
    echo "Could not load configuration file. Abort."
    exit 1
fi
echo " OK"

# set default values
: ${REMEMBER_ONSITE_REVERSE_PORT:=2222}
: ${REMEMBER_OFFSITE_USER:=root}

echo -n "Check that the reverse SSH tunnel exists"
if ! ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost exit; then
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

#TODO: decrypt backup at some early stage

echo -n "Check remote base directory..."
if ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "[ ! -d $REMEMBER_BASEPATH ]"; then
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
if ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "[ -d $REMEMBER_DEST ]"; then
    if ! ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "rm -rf $REMEMBER_DEST"; then
        echo " FAIL"
        echo "Failed in removing stale remote directory \"$REMEMBER_DEST\". Abort."
        exit 1
    fi
fi

if ! ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "mkdir $REMEMBER_DEST"; then
    echo " FAIL"
    echo "Creating remote directory \"$REMEMBER_DEST\" failed. Abort."
    exit 1
fi
echo " OK"

echo -n "Check remote destination directory (previous)..."
REMEMBER_LINKDEST=$REMEMBER_BASEPATH/previous
# "previous" directory contains last successful backup, if it does not exist
# then create an empty directory for rsync to diff against
if ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "[ ! -d $REMEMBER_LINKDEST ]"; then
    if ! ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "mkdir $REMEMBER_LINKDEST"; then
        echo " FAIL"
        echo "Creating remote directory \"$REMEMBER_LINKDEST\" failed. Abort."
        exit 1
    fi
fi
echo " OK"

echo -n "Checking remote rsync permissions..."
REMEMBER_RSYNC_PERMISSION=/etc/sudoers.d/01_remember-backup
if ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "[ ! -e $REMEMBER_RSYNC_PERMISSION ]"; then
    echo " FAIL"
    echo "Missing rsync permission file $REMEMBER_RSYNC_PERMISSION. Manually copy to remote machine. Abort."
    exit 1
fi
echo " OK"

echo -n "Running rsync..."
#           --progress \
#           --stats \
if ! rsync --archive \
           --rsh="ssh -p$REMEMBER_ONSITE_REVERSE_PORT" --rsync-path="sudo rsync" \
           --delete-before --delete-excluded --prune-empty-dirs \
           --link-dest=$REMEMBER_LINKDEST \
           $REMEMBER_SOURCE $REMEMBER_OFFSITE_USER@localhost:$REMEMBER_DEST; then
#if (( $? != 0 )); then
    echo " FAIL"
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

# TODO: Check if following are defined, if not set them empty in the variable, e.g. {;26;24;;}
# TODO: read the parameter in remember-rotate
#REMEMBER_MAX_DAILY=7
#REMEMBER_MAX_WEEKLY=52
#REMEMBER_MAX_MONTHLY=12
#REMEMBER_MAX_YEARLY=99
if ! ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "$REMEMBER_ROTATE $REMEMBER_BASEPATH $REMEMBER_DEST"; then
    echo " FAIL"
    echo "Failed execution of $REMEMBER_ROTATE. Abort."
    exit 1
fi

echo -n "Cleaning up..."
if ! ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "rm $REMEMBER_ROTATE"; then
    echo " FAIL"
    echo "Failed removal of $REMEMBER_ROTATE. Abort."
    exit 1
fi

# Consider $REMEMBER_CURRENT as consumed due to the hardlinks to atleast daily.0 
# in the rotated structure. Move to $REMEMBER_LAST so that e.g. hardlinking 
# rsync backups have something to compare against.
if ! ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "rm -rf $REMEMBER_LINKDEST"; then
    echo " FAIL"
    echo "Failed while removing $REMEMBER_LINKDEST. Abort."
    exit 1
fi

if ! ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost "mv $REMEMBER_DEST $REMEMBER_LINKDEST"; then
    echo " FAIL"
    echo "Failed while moving $REMEMBER_DEST. Abort."
    exit 1
fi
echo " OK"

# TODO: encrypt backup
