#!/bin/bash

TEST_BOARD_WIDTH=9
TEST_BOARD_HEIGHT=9
SAMPLE_SIZE=7

echo
echo "======================================================================="
echo "Performing Scaling Tests"
echo "======================================================================="
export GOBOT_THINK_TIME=500
export GOBOT_BATCH_SIZE=1
for nthreads in 1 2 4 8 16 32; do
    export X10_NTHREADS=$nthreads
    echo
    echo "-----------------------------------------------------------------------"
    echo "<X10_NTHREADS=$X10_NTHREADS, GOBOT_BATCH_SIZE=$GOBOT_BATCH_SIZE, GOBOT_THINK_TIME=$GOBOT_THINK_TIME>"
    echo "-----------------------------------------------------------------------"
    ./TestGo $TEST_BOARD_WIDTH $TEST_BOARD_HEIGHT $SAMPLE_SIZE 
done

echo
echo "======================================================================="
echo "Performing Parameter Tests"
echo "======================================================================="
export X10_NTHREADS=32
export GOBOT_THINK_TIME=500
for batch_size in 1 2 4 8 16 32; do
    export GOBOT_BATCH_SIZE=$batch_size
    echo
    echo "-----------------------------------------------------------------------"
    echo "<X10_NTHREADS=$X10_NTHREADS, GOBOT_BATCH_SIZE=$GOBOT_BATCH_SIZE, GOBOT_THINK_TIME=$GOBOT_THINK_TIME>"
    echo "-----------------------------------------------------------------------"
    ./TestGo $TEST_BOARD_WIDTH $TEST_BOARD_HEIGHT $SAMPLE_SIZE 
done

echo
echo "======================================================================="
echo "Performing Budget Tests"
echo "======================================================================="
export GOBOT_BATCH_SIZE=1
export X10_NTHREADS=1
for think_time in 100 500 1000 3000 6000; do
    export GOBOT_THINK_TIME=$think_time
    echo
    echo "-----------------------------------------------------------------------"
    echo "<X10_NTHREADS=$X10_NTHREADS, GOBOT_BATCH_SIZE=$GOBOT_BATCH_SIZE, GOBOT_THINK_TIME=$GOBOT_THINK_TIME>"
    echo "-----------------------------------------------------------------------"
    ./TestGo $TEST_BOARD_WIDTH $TEST_BOARD_HEIGHT $SAMPLE_SIZE 
done

echo
echo "======================================================================="
echo "Performing 18x18 Test"
echo "======================================================================="
export GOBOT_THINK_TIME=500
export GOBOT_BATCH_SIZE=4
export X10_NTHREADS=32
echo
echo "-----------------------------------------------------------------------"
echo "<X10_NTHREADS=$X10_NTHREADS, GOBOT_BATCH_SIZE=$GOBOT_BATCH_SIZE, GOBOT_THINK_TIME=$GOBOT_THINK_TIME>"
echo "-----------------------------------------------------------------------"
./TestGo 18 18 $SAMPLE_SIZE 