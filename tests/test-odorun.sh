#!/bin/bash

# Command to invoke odounit.sh
CMD=../odorun.sh

# For debugging tracing is logged here
TRACE=/tmp/odorun-test-trace.log

# Output of odorun.sh is logged here
CMD_LOG=/tmp/odorun-test.log

function setUp() {
    truncate -s 0 "$CMD_LOG"
    truncate -s 0 "$TRACE"
}

function trace() {
    echo "$1" >>"$TRACE" 2>&1
}

function testSuccess() {
    assertTrue "[ 1 ]"
}

. shunit2
