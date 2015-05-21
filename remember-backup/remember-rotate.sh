#!/bin/bash 

# TODO:
# * implement "du -sh" on remote filesystem

#TODO: read parameters from configfile add CURRENT and LAST...

if (( $# == 0 )); then
    echo -n "Reading configuration from file..."
    if source $(readlink -f $0 | xargs dirname)/remember-rotate.conf 2>/dev/null; then
        echo " FAIL"
        echo "Could not load configuration file. Abort."
        exit 1
    fi
else
    echo -n "Reading configuration from command line..."
    REMEMBER_BASEPATH=$1
    REMEMBER_CURRENT=$2
    REMEMBER_MAX_DAILY=$4
    REMEMBER_MAX_WEEKLY=$5
    REMEMBER_MAX_MONTHLY=$6
    REMEMBER_MAX_YEARLY=$7
fi

orig_basepath=$REMEMBER_BASEPATH
if [ ! "${REMEMBER_BASEPATH:0:1}" = "/" ]; then
    REMEMBER_BASEPATH=$(readlink -f $0 | xargs dirname)/$REMEMBER_BASEPATH
fi

if [ ! -d $REMEMBER_BASEPATH ]; then
    echo " FAIL"
    echo "Missing directory \"$orig_basepath\". Abort."
    exit 1
fi

# set default values
: ${REMEMBER_MAX_DAILY:=7}
: ${REMEMBER_MAX_WEEKLY:=52}
: ${REMEMBER_MAX_MONTHLY:=12}
: ${REMEMBER_MAX_YEARLY:=99}
: ${REMEMBER_CURRENT:=$REMEMBER_BASEPATH/current}

REMEMBER_DIR_DAILY=$REMEMBER_BASEPATH/daily
REMEMBER_DIR_WEEKLY=$REMEMBER_BASEPATH/weekly
REMEMBER_DIR_MONTHLY=$REMEMBER_BASEPATH/monthly
REMEMBER_DIR_YEARLY=$REMEMBER_BASEPATH/yearly
echo " OK"

echo -n "Checking availability of new data to rotate..."
if [ ! -e $REMEMBER_CURRENT ];  then
    echo " FAIL"
    echo "There is no incoming backup to rotate. Abort."
    exit 1
fi
echo " OK"

echo -n "Checking the directory stucture..."
if [ ! -d $REMEMBER_DIR_DAILY ];   then mkdir -p $REMEMBER_DIR_DAILY; fi
if [ ! -d $REMEMBER_DIR_WEEKLY ];  then mkdir -p $REMEMBER_DIR_WEEKLY; fi
if [ ! -d $REMEMBER_DIR_MONTHLY ]; then mkdir -p $REMEMBER_DIR_MONTHLY; fi
if [ ! -d $REMEMBER_DIR_YEARLY ];  then mkdir -p $REMEMBER_DIR_YEARLY; fi
echo " OK"

# Check for missing backups based on file names. 
# Considered critical as backups may be missing due to script bug or accidental deletion.
echo -n "Checking file structure..."
for directory in $REMEMBER_DIR_DAILY $REMEMBER_DIR_WEEKLY $REMEMBER_DIR_MONTHLY $REMEMBER_DIR_YEARLY; do
    template=$(basename $directory)
    count=$(find $directory -maxdepth 1 -name $template.* | wc -l)
    for i in $( seq 0 1 $((count - 1)) ); do
        if [ ! -e $directory/$template.$i ]; then
            echo " FAIL"
            echo "Backup rotation structure is corrupt. Item \"$directory/$template.$i\" is missing. Abort."
            exit 1
        fi
    done
done
echo " OK"

do_rotate() {
    directory=$1
    template=$(basename $directory)
    max_count=$2
    
    count=$(find $directory -maxdepth 1 -name $template.* | wc -l) 
    
    # rotate
    for i in $( seq $count -1 1 ); do
        mv $directory/$template.$((i - 1)) $directory/$template.$i
    done
    
    # store
    if [ ! -e $directory/$template.0 ]; then
        cp -r -l $REMEMBER_CURRENT $directory/$template.0
    else
        echo "Rotation of the daily content failed. Abort."
        exit 1
    fi
    
    # prune
    for i in $( seq $max_count 1 $count  ); do
        rm -rf $directory/$template.$i
    done
}

#
# ROTATE DAILY
#
last=$REMEMBER_DIR_DAILY/$(basename $REMEMBER_DIR_DAILY).0
# perform some sanity tests
if [ -e $last ]; then
    if   (( $(date -r $last +%s) > $(date -r $REMEMBER_CURRENT +%s) )); then
        echo "Current backup is older that last daily. Nothing to do. Stop."
        exit 0
    elif (( $(date -r $last +%Y) == $(date -r $REMEMBER_CURRENT +%Y) )) && \
         (( $(date -r $last +%j) >= $(date -r $REMEMBER_CURRENT +%j) )); then
        echo "Current backup is not atleast one day older that last daily. Nothing to do. Stop."
        exit 0
    fi
fi

#
# ROTATE DAILY
#
echo -n "Rotating daily..."
do_rotate $REMEMBER_DIR_DAILY $REMEMBER_MAX_DAILY 
echo " OK"

#
# ROTATE WEEKLY
#
echo -n "Rotating weekly..."
if (( $(date -r $REMEMBER_CURRENT +%u) == 7 )); then
    do_rotate $REMEMBER_DIR_WEEKLY $REMEMBER_MAX_WEEKLY
    echo " OK"
else
    echo " Nothing to do."
fi

#
# ROTATE MONTHLY
#
currentdayofmonth=$(date -r $REMEMBER_CURRENT +%d)
currentmonth=$(date -r $REMEMBER_CURRENT +%m)
currentyear=$(date -r $REMEMBER_CURRENT +%Y)
lastdayofcurrentmonth=$(date -d "$currentmonth/1/$currentyear + 1 month - 1 day" +%d)
echo -n "Rotating monthly..."
currentdayofmonth=$(( 10#$currentdayofmonth ))
lastdayofcurrentmonth=$(( 10#$lastdayofcurrentmonth ))
if (( $currentdayofmonth == $lastdayofcurrentmonth )); then
    do_rotate $REMEMBER_DIR_MONTHLY $REMEMBER_MAX_MONTHLY
    echo " OK"
else
    echo " Nothing to do."
fi

#
# ROTATE YEARLY
#
currentdayofmonth=$(date -r $REMEMBER_CURRENT +%d)
currentmonth=$(date -r $REMEMBER_CURRENT +%m)
echo -n "Rotation yearly..."
if (( $currentmonth == 12 )) && (( $currentdayofmonth == 31 )); then
    do_rotate $REMEMBER_DIR_YEARLY $REMEMBER_MAX_YEARLY
    echo " OK"
else
    echo " Nothing to do."
fi

#
# POST-CHECK
# Warn user for missing backups based on time deltas.
# Not considered critical as the script will function properly 
# but may shown problems with the backup scheduling mechanism. 
do_postcheck() {
    directory=$1
    diff_func=$2
    template=$(basename $directory)
    echo -n "Checking consistency of backup schedule in $template..."
    count=$(find $directory -maxdepth 1 -name $template.* | wc -l)
    failed=0
    if (( count >= 2 )); then
        # +%F will truncate to whole days, 
        # +%s will get the age in seconds of that day
        previousfile="$directory/$template.0"
        for i in $( seq 1 1 $((count - 1)) ); do
                currentfile="$directory/$template.$i"
                diff=$($diff_func $previousfile $currentfile)
               if (( $diff > 1 )); then
                    if (( "$failed" == 0 )); then
                        echo " WARNING"
                        failed=1
                    fi
                    echo "INFO: Missing $(( $diff - 1 )) backup(s) between $(basename $previousfile) and $(basename $currentfile)."
                fi
                previousfile=$currentfile
        done
    fi
    if (( "$failed" == 0 )); then
        echo " OK"
    fi
}

diff_daily() {
    local previousfile=$1
    local currentfile=$2
    local previousdate=$(date -d "$(date -r $previousfile +%F)" +%s)
    local currentdate=$(date -d "$(date -r $currentfile +%F)" +%s)
    # simply using $(( )) will fail during daylight saving as
    # the diff will fall an hour short and return a float that is then
    # floored by $(( ))...
    #diff=$(( ($previousdate - $currentdate) / (24*3600) ))
 
    # some locales "bc" and "printf" return/require different decimal points
    # fix that with a "sed" replace
    echo $(printf "%.0f" $(echo "scale=2; ($previousdate - $currentdate)/(3600*24)" | bc | sed "s/\./,/"))
}

diff_weekly() {
    local previousfile=$1
    local currentfile=$2
    local previousdate=$(date -d "$(date -r $previousfile +%F)" +%s)
    local currentdate=$(date -d "$(date -r $currentfile +%F)" +%s)
    # simply using $(( )) will fail during daylight saving as
    # the diff will fall an hour short and return a float that is then
    # floored by $(( ))...
    #diff=$(( ($previousdate - $currentdate) / (24*3600*7) ))
 
    # some locales "bc" and "printf" return/require different decimal points
    # fix that with a "sed" replace
    echo $(printf "%.0f" $(echo "scale=2; ($previousdate - $currentdate)/(3600*24*7)" | bc | sed "s/\./,/"))
}

diff_monthly() {
    local previousfile=$1
    local currentfile=$2
    local previousyear=$(date -r $previousfile +%Y)
    # converting to base 10 drops leading zeroes in the month returned by date
    local previousmonth=$((10#$(date -r $previousfile +%m) ))
    local currentyear=$(date -r $currentfile +%Y)
    # converting to base 10 drops leading zeroes in the month returned by date
    local currentmonth=$((10#$(date -r $currentfile +%m) ))
    echo $(( ($previousyear-$currentyear)*12 + ($previousmonth - $currentmonth) ))
}   

diff_yearly() {
    local previousfile=$1
    local currentfile=$2
    local previousyear=$(date -r $previousfile +%Y)
    local currentyear=$(date -r $currentfile +%Y)
    echo $(( $previousyear - $currentyear ))
}

do_postcheck $REMEMBER_DIR_DAILY diff_daily
do_postcheck $REMEMBER_DIR_WEEKLY diff_weekly
do_postcheck $REMEMBER_DIR_MONTHLY diff_monthly
do_postcheck $REMEMBER_DIR_YEARLY diff_yearly
