#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

touch -d "5/6/2015" $CURRENT
touch -d "5/5/2015" $DAILY/daily.0
