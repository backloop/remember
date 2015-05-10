#!/bin/bash -x

echo -n "Reading configuration..."
. $(readlink -f $0 | xargs dirname)/remember-backup.conf 2>/dev/null
if [ ! $? = 0 ]; then
    echo " FAIL"
    echo "Could not load configuration file. Abort."
    exit 1
fi

# set default values
: ${REMEMBER_ONSITE_REVERSE_PORT:=2222}
: ${REMEMBER_OFFSITE_USER:=root}

if ! ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost exit; then
    echo " FAIL"
    echo "Reverse SSH tunnel not active. Abort."
    exit 1
fi

if [ ! -d $REMEMBER_SOURCE ]; then
    echo " FAIL"
    echo "Missing directory \"$REMEMBER_SOURCE\". Abort."
    exit 1
fi

if [ "not" == "$(ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost [ ! -d $REMEMBER_DEST ] && echo "not")" ]; then
    echo " FAIL"
    echo "Missing directory \"$REMEMBER_DEST\". Abort."
    exit 1
fi

if [ "not" == "$(ssh -p$REMEMBER_ONSITE_REVERSE_PORT $REMEMBER_OFFSITE_USER@localhost [ ! -d $REMEMBER_LINKDEST ] && echo "not")" ]; then
    echo " FAIL"
    echo "Missing directory \"$REMEMBER_LINKDEST\". Abort."
    exit 1
fi
echo " OK"

echo -n "Running rsync..."
rsync   --archive --stats --progress \
        --rsh="ssh -p$REMEMBER_ONSITE_REVERSE_PORT" --rsync-path="sudo rsync" \
        --delete-before --delete-excluded --prune-empty-dirs \
        --link-dest=$REMEMBER_LINKDEST \
        $REMEMBER_SOURCE $REMEMBER_OFFSITE_USER@localhost:$REMEMBER_DEST
if (( $? == 0 )); then
    echo " OK"
else
    echo " FAIL"
fi
