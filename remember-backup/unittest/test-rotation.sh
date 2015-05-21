#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

touch -d "5/6/2015" $CURRENT
touch -d "5/5/2015" $DAILY/daily.0
touch -d "5/4/2015" $DAILY/daily.1
touch -d "5/3/2015" $DAILY/daily.2
touch -d "5/2/2015" $DAILY/daily.3
touch -d "5/1/2015" $DAILY/daily.4
touch -d "4/30/2015" $DAILY/daily.5
touch -d "4/29/2015" $DAILY/daily.6
touch -d "4/28/2015" $DAILY/daily.7
touch -d "4/27/2015" $DAILY/daily.8
