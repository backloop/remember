#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

touch -d "3/31/2016" $CURRENT
touch -d "2/29/2016" $MONTHLY/monthly.0
