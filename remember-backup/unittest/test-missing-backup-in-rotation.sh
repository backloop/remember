#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

touch -d "5/6/2015" $BASEPATH/current
touch -d "5/5/2015" $DAILY/daily.0
#touch -d "5/4/2015" $DAILY/daily.1
touch -d "5/3/2015" $DAILY/daily.2