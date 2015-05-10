#!/bin/bash

BASEPATH=$(readlink -f $0 | xargs dirname)/test

DAILY=$BASEPATH/daily
WEEKLY=$BASEPATH/weekly
MONTHLY=$BASEPATH/monthly
YEARLY=$BASEPATH/yearly

rm -rf $BASEPATH
mkdir -p $DAILY
mkdir -p $WEEKLY
mkdir -p $MONTHLY
mkdir -p $YEARLY
