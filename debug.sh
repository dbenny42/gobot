#!/bin/bash

export UCT_DETAIL=$((1<<0))
export TP_DETAIL=$((1<<1))
export DP_DETAIL=$((1<<2))
export BP_DETAIL=$((1<<3))
export TP_ITR_DETAIL=$((1<<4))
export GBC_DETAIL=$((1<<5))
export BOARD_DETAIL=$((1<<10))
export ALL_DETAIL=$(($UCT_DETAIL|$TP_DETAIL|$DP_DETAIL|$TP_ITR_DETAIL|$GBC_DETAIL|$BOARD_DETAIL))
export DEFAULT_DETAIL=$ALL_DETAIL
export GOBOT_DEBUG=$DEFAULT_DETAIL