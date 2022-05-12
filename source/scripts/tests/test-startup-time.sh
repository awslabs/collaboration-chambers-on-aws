#!/bin/bash -ex

test_script=$1

script=$(basename $0)

et_file=/tmp/${script}-$(basename ${test_script})-et.txt

time=/usr/bin/time

$time -f %e -o $et_file qsub -W block=true ${test_script}

echo "Elapsed time (s): $(cat $et_file)"
