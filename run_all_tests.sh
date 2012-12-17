#!/bin/bash

TEST_BOARD_WIDTH=9
TEST_BOARD_HEIGHT=9
SAMPLE_SIZE=1
export X10_NTHREADS=32
export GOBOT_THINK_TIME=3
export GOBOT_BATCH_SIZE=8


./TestGo $TEST_BOARD_WIDTH $TEST_BOARD_HEIGHT $SAMPLE_SIZE 

# Perform Scaling Tests
# export GOBOT_THINK_TIME=3
# export GOBOT_BATCH_SIZE=1
# for nthreads in 1 2 4 8 16 32; do
#     export X10_NTHREADS=$nthreads
#     ./TestGo $TEST_BOARD_WIDTH $TEST_BOARD_HEIGHT $SAMPLE_SIZE 
# done


# # Perform Parameter Tests
# export X10_NTHREADS=32
# for batch_size in 1 2 4 8 16 32; do
#     export GOBOT_BATCH_SIZE=$batch_size
#     ./TestGo $TEST_BOARD_WIDTH $TEST_BOARD_HEIGHT $SAMPLE_SIZE 
# done


# # Perform Budget Tests
# export GOBOT_BATCH_SIZE=8
# for think_time in 1 2 3 4 5; do
#     export GOBOT_THINK_TIME=$think_time
#     ./TestGo $TEST_BOARD_WIDTH $TEST_BOARD_HEIGHT $SAMPLE_SIZE 
# done

# # Perform 18x18 Test
# export GOBOT_THINK_TIME=5
# ./TestGo $TEST_BOARD_WIDTH $TEST_BOARD_HEIGHT $SAMPLE_SIZE 