#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

touch -d "2 day ago" $BASEPATH/current
touch -d "1 day ago" $DAILY/daily.0
