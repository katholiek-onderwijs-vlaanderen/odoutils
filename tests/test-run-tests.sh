#!/bin/bash

#../run-tests.sh --plain --once module_without_failures >/tmp/run-test.log
#if [ "$?" -ne 0 ]; then
#    echo "FAILED: should have returned exit code 0, indicating all tests passed."
#    exit 1
#fi
#exit 0

TRACE=/tmp/test-run-tests.log

function setUp() {
    ../run-tests.sh --remove >$TRACE 2>&1
}

function tearDownOnce() {
    ../run-tests.sh --remove >>$TRACE 2>&1
}

function testSuccess() {
    assertEquals "Testing module_wihout_failures should return with exit code 0" \
        $(../run-tests.sh --plain --once module_without_failures >/tmp/run-test.log; echo $?) 0
}

function testFailure() {
    assertEquals "Testing module_wih_failures should return with exit code 1" \
        $(../run-tests.sh --plain --once module_with_failures >/tmp/run-test.log; echo $?) 1
}

. shunit2
