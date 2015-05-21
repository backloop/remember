#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

touch -d "12/31/2016" $CURRENT
touch -d "12/31/2015" $YEARLY/yearly.0
