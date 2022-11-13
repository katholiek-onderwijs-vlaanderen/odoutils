#!/bin/bash

# Command to invoke odounit.sh
CMD=../odounit.sh

# For debugging tracing is logged here
TRACE=/tmp/odounit-test-trace.log

# Output of odounit.sh is logged here
CMD_LOG=/tmp/odounit-test.log

function setUpOnce() {
    truncate "$CMD_LOG"
    truncate "$TRACE"
}

function trace() {
    echo "$1" >>"$TRACE" 2>&1
}

function testSuccess() {
    trace "Testing happy path. Executing test suite for module_wihout_failure."
    "$CMD" -p -o module_without_failures >$CMD_LOG
    RET=$?
    trace "Return value was [$RET]."

    trace "Checking return value was 0."
    assertEquals "Testing module_without_failures should return with exit code 0" 0 $RET
    trace "testSuccess done."
}

function testFailure() {
    trace "Testing for correct detection of failures. Executing test suite for module_with_failure."
    "$CMD" -p -o module_with_failures >$CMD_LOG
    RET=$?
    trace "Return value was [$RET]."

    trace "Checking return value was 0."
    assertEquals "Testing module_with_failures should return with exit code 1" 1 $RET
    trace "testFailure done."
}

function testUnknown() {
    "$CMD" -p -o module_does_not_run_tests >$CMD_LOG
    RET=$?

    assertEquals "Testing module_does_not_run_tests should return with exit code 2" 2 $RET
}

function testRunWithoutOptionPlainOutputsColor() {
    "$CMD" -o module_without_failures >"$CMD_LOG" 2>&1
    cat "$CMD_LOG" | sed 's/\x1b\[[0-9;]*[mGKHF]//g' >"$CMD_LOG.stripped" 2>&1
    hash_original=$(cat "$CMD_LOG" | md5sum)
    hash_filtered=$(cat "$CMD_LOG.stripped" | md5sum)
    trace "Hash of output: $hash_original"
    trace "Hash of filtered output: $hash_filtered"

    assertNotEquals "Running tests without -p should output color." "$hash_original" "$hash_filtered"
}

function testRunWithOptionPlainOutputsNoColor() {
    "$CMD" -o -p module_without_failures >"$CMD_LOG" 2>&1
    cat "$CMD_LOG" | sed 's/\x1b\[[0-9;]*[mGKHF]//g' >"$CMD_LOG.stripped" 2>&1
    hash_original=$(cat "$CMD_LOG" | md5sum)
    hash_filtered=$(cat "$CMD_LOG.stripped" | md5sum)
    trace "Hash of output: $hash_original"
    trace "Hash of filtered output: $hash_filtered"

    assertEquals "Running tests with -p should NOT output color." "$hash_original" "$hash_filtered"
}

function testRunWithOptionHelpOutputsHelp() {
    "$CMD" -h >"$CMD_LOG" 2>&1

    assertNotEquals "Running with -h should output Usage help." 0 $(cat $CMD_LOG | grep "Usage" | wc -l)
    assertNotEquals "Running with -h should output Options help." 0 $(cat $CMD_LOG | grep "Options" | wc -l)
    assertNotEquals "Running with -h should output Examples help." 0 $(cat $CMD_LOG | grep "Examples" | wc -l)
}

function testNoOptionsShowsUsage() {
    "$CMD" >"$CMD_LOG" 2>&1

    assertNotEquals "Running without any parameters should output Usage." 0 $(cat $CMD_LOG | grep "Usage" | wc -l)
}

function testRemoveContainers() {
    trace "First checking if there are docker containers."
    if [ $(docker ps -a | grep 'run-odoo-tests' | wc -l) -eq 0 ]; then
        trace "Did not find any - creating them."
        "$CMD" -o -p module_without_failures >"$CMD_LOG" 2>&1
    else
        trace "There are some."
    fi

    trace "Removing docker containers."
    "$CMD" -r >"$CMD_LOG" 2>&1

    trace "Checking that they were deleted."
    assertTrue "All docker containers should be removed." "[ $(docker ps -a | grep 'run-odoo-tests' | wc -l) -eq 0 ]"
}

function testNonExistingModule() {
    trace "Trying to start with a non-existing module."
    "$CMD" -o -p does_not_exist >"$CMD_LOG" 2>&1
    RET=$?

    assertNotEquals "Starting with a non-existing module, should fail with exit code > 0" 0 $RET
}

function testOdoo14() {
    trace "Trying to run tests on odoo 14."
    "$CMD" -o -p -g 14 module_without_failures >"$CMD_LOG" 2>&1
    RET=$?

    assertEquals "Running on odoo 14 should exit with success code 0." 0 $RET
}

function testOdoo16() {
    trace "Trying to run tests on odoo 14."
    "$CMD" -o -p -g 16 module_without_failures >"$CMD_LOG" 2>&1
    RET=$?

    assertEquals "Running on odoo 16 should exit with success code 0." 0 $RET
}

. shunit2
