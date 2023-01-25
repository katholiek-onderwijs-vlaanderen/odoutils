#!/bin/bash

# Command to invoke odounit.sh
CMD=../odounit.sh

# For debugging tracing is logged here
TRACE=/tmp/odounit-test-trace.log

# Output of odounit.sh is logged here
CMD_LOG=/tmp/odounit-test.log

function setUp() {
  truncate -s 0 "$TRACE"
  truncate -s 0 "$CMD_LOG"
}

function trace() {
    echo "$1" >>"$TRACE" 2>&1
}

function testUnknown() {
    "$CMD" -p -o module_with_missing_dependency >$CMD_LOG
    RET=$?

    assertEquals "Testing module_with_missing_dependencies should run with failed install." 2 $RET
}

. shunit2
