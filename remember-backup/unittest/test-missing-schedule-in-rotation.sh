#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

# daily is a bt special because "current" will be rotated into the
# file structure during the executon of remember-rotate.sh. 
# The correct output is:
#INFO: Missing 1 backup(s) between daily.0 and daily.1.
#INFO: Missing 2 backup(s) between daily.2 and daily.3.
touch -d "5/6/2015" $CURRENT
touch -d "5/4/2015" $DAILY/daily.0 
touch -d "5/3/2015" $DAILY/daily.1
touch -d "4/30/2015" $DAILY/daily.2
touch -d "4/29/2015" $DAILY/daily.3

# The correct output is:
#INFO: Missing 1 backup(s) between weekly.0 and weekly.1.
#INFO: Missing 2 backup(s) between weekly.2 and weekly.3.
touch -d "5/3/2015" $WEEKLY/weekly.0
touch -d "4/19/2015" $WEEKLY/weekly.1
touch -d "4/12/2015" $WEEKLY/weekly.2
touch -d "3/22/2015" $WEEKLY/weekly.3
touch -d "3/15/2015" $WEEKLY/weekly.4

# The correct output is:
#INFO: Missing 1 backup(s) between monthly.0 and monthly.1.
#INFO: Missing 2 backup(s) between monthly.2 and monthly.3.
touch -d "4/30/2015" $MONTHLY/monthly.0
touch -d "2/28/2015" $MONTHLY/monthly.1 # change to a leapyear
touch -d "1/31/2015" $MONTHLY/monthly.2
touch -d "10/31/2014" $MONTHLY/monthly.3
touch -d "9/30/2014" $MONTHLY/monthly.4

# The correct output is:
#INFO: Missing 1 backup(s) between yearly.0 and yearly.1.
#INFO: Missing 2 backup(s) between yearly.2 and yearly.3.
touch -d "12/31/2014" $YEARLY/yearly.0
touch -d "12/31/2012" $YEARLY/yearly.1
touch -d "12/31/2011" $YEARLY/yearly.2
touch -d "12/31/2008" $YEARLY/yearly.3
touch -d "12/31/2007" $YEARLY/yearly.4
