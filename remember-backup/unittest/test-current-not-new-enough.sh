#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

touch -d "now" $CURRENT
touch -d "4 hour ago" $DAILY/daily.0
