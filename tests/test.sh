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
    assertEquals "Testing module_wihout_failures should return with exit code 0" \
        $($CMD --plain --once module_without_failures >$CMD_LOG; echo $?) 0
}

function testFailure() {
    assertEquals "Testing module_wih_failures should return with exit code 1" \
        $($CMD --plain --once module_with_failures >$CMD_LOG; echo $?) 1
}

function testUnknown() {
    assertEquals "Testing module_does_not_run_tests should return with exit code 2" \
        $($CMD --plain --once module_does_not_run_tests >$CMD_LOG; echo $?) 2
}

function testRunWithoutOptionPlainOutputsColor() {
    "$CMD" --once module_without_failures >"$CMD_LOG" 2>&1
    cat "$CMD_LOG" | sed 's/\x1b\[[0-9;]*[mGKHF]//g' >"$CMD_LOG.stripped" 2>&1
    hash_original=$(cat "$CMD_LOG" | md5sum)
    hash_filtered=$(cat "$CMD_LOG.stripped" | md5sum)
    trace "Hash of output: $hash_original"
    trace "Hash of filtered output: $hash_filtered"

    assertNotEquals "Running tests without --plain should output color." "$hash_original" "$hash_filtered"
}

function testRunWithOptionPlainOutputsNoColor() {
    "$CMD" --once --plain module_without_failures >"$CMD_LOG" 2>&1
    cat "$CMD_LOG" | sed 's/\x1b\[[0-9;]*[mGKHF]//g' >"$CMD_LOG.stripped" 2>&1
    hash_original=$(cat "$CMD_LOG" | md5sum)
    hash_filtered=$(cat "$CMD_LOG.stripped" | md5sum)
    trace "Hash of output: $hash_original"
    trace "Hash of filtered output: $hash_filtered"

    assertEquals "Running tests with --plain should NOT output color." "$hash_original" "$hash_filtered"
}

function testRunWithOptionHelpOutputsHelp() {
    "$CMD" --help >"$CMD_LOG" 2>&1

    assertNotEquals "Running with --help should output Usage help." $(cat $CMD_LOG | grep "Usage" | wc -l) 0
    assertNotEquals "Running with --help should output Options help." $(cat $CMD_LOG | grep "Options" | wc -l) 0
    assertNotEquals "Running with --help should output Examples help." $(cat $CMD_LOG | grep "Examples" | wc -l) 0
}

function testNoOptionsShowsUsage() {
    "$CMD" >"$CMD_LOG" 2>&1

    assertNotEquals "Running without any parameters should output Usage." $(cat $CMD_LOG | grep "Usage" | wc -l) 0
}

. shunit2
