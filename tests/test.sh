#!/bin/bash

#../run-tests.sh --plain --once module_without_failures >/tmp/run-test.log
#if [ "$?" -ne 0 ]; then
#    echo "FAILED: should have returned exit code 0, indicating all tests passed."
#    exit 1
#fi
#exit 0

TRACE=/tmp/test-run-tests.log
CMD=../run-tests.sh
LOG=/tmp/test-run-tests-output.log

function setUpOnce() {
    truncate "$LOG"
    truncate "$TRACE"
}

function trace() {
    echo "$1" >>"$TRACE" 2>&1
}

function testSuccess() {
    assertEquals "Testing module_wihout_failures should return with exit code 0" \
        $($CMD --plain --once module_without_failures >/tmp/run-test.log; echo $?) 0
}

function testFailure() {
    assertEquals "Testing module_wih_failures should return with exit code 1" \
        $($CMD --plain --once module_with_failures >/tmp/run-test.log; echo $?) 1
}

function testUnknown() {
    assertEquals "Testing module_does_not_run_tests should return with exit code 2" \
        $($CMD --plain --once module_does_not_run_tests >/tmp/run-test.log; echo $?) 2
}

function testRunWithoutOptionPlainOutputsColor() {
    "$CMD" --once module_without_failures >"$LOG" 2>&1
    cat "$LOG" | sed 's/\x1b\[[0-9;]*[mGKHF]//g' >"$LOG.stripped" 2>&1
    hash_original=$(cat "$LOG" | md5sum)
    hash_filtered=$(cat "$LOG.stripped" | md5sum)
    trace "Hash of output: $hash_original"
    trace "Hash of filtered output: $hash_filtered"

    assertNotEquals "Running tests without --plain should output color." "$hash_original" "$hash_filtered"
}

function testRunWithOptionPlainOutputsNoColor() {
    "$CMD" --once --plain module_without_failures >"$LOG" 2>&1
    cat "$LOG" | sed 's/\x1b\[[0-9;]*[mGKHF]//g' >"$LOG.stripped" 2>&1
    hash_original=$(cat "$LOG" | md5sum)
    hash_filtered=$(cat "$LOG.stripped" | md5sum)
    trace "Hash of output: $hash_original"
    trace "Hash of filtered output: $hash_filtered"

    assertEquals "Running tests with --plain should NOT output color." "$hash_original" "$hash_filtered"
}

function testRunWithOptionHelpOutputsHelp() {
    "$CMD" --help >"$LOG" 2>&1

    assertNotEquals "Running with --help should output Usage help." $(cat $LOG | grep "Usage" | wc -l) 0
    assertNotEquals "Running with --help should output Options help." $(cat $LOG | grep "Options" | wc -l) 0
    assertNotEquals "Running with --help should output Examples help." $(cat $LOG | grep "Examples" | wc -l) 0
}

function testNoOptionsShowsUsage() {
    "$CMD" >"$LOG" 2>&1

    assertNotEquals "Running without any parameters should output Usage." $(cat $LOG | grep "Usage" | wc -l) 0
}

. shunit2
