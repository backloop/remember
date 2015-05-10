#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

touch -d "3/31/2015" $BASEPATH/current
touch -d "2/28/2015" $MONTHLY/monthly.0
