#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

touch -d "5/3/2015" $BASEPATH/current
touch -d "4/26/2015" $WEEKLY/weekly.0
