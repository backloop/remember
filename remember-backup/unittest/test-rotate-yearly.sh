#!/bin/bash

. $(readlink -f $0 | xargs dirname)/test-setup.sh

touch -d "12/31/2014" $BASEPATH/current
touch -d "12/31/2013" $YEARLY/yearly.0
