#!/usr/bin/env bash
OUTPUT=/tmp/loop-tests.log
TIME=/tmp/loop-tests-time.log

function calculate_hash {
	echo $(find tests odorun.sh odounit.sh runtests.sh -type f -exec ls -l --full-time {} + | sort | md5sum)
}

# Output big text with figlet
# Fixes issue with background color sequence not getting applied correctly.
# First clear to end of line for 6 line, then re-positiotn cursor back up, then output figlet.
# $1 message to display
function big_text {
	echo "$(tput el)"
	echo "$(tput el)"
	echo "$(tput el)"
	echo "$(tput el)"
	echo "$(tput el)"
	echo "$(tput el)"
	echo -n "$(tput cuu1)"
	echo -n "$(tput cuu1)"
	echo -n "$(tput cuu1)"
	echo -n "$(tput cuu1)"
	echo -n "$(tput cuu1)"
	echo -n "$(tput cuu1)"
	figlet -t -c "$1"
}

# Show green message
# $1: message
function show_success_msg {
	echo "$(tput bold)$(tput setaf 7)$(tput setab 2)"
	echo
	big_text "$1"
	big_text "Passed"
	echo $(tput sgr 0)
}

# Show red message
# $1: message
function show_fail_msg {
	echo "$(tput bold)$(tput setaf 7)$(tput setab 1)"
	echo
	big_text "$1"
	big_text "FAILED!"
	echo $(tput sgr 0)
}

function run_tests {
	#clear
	[ -f $OUTPUT ] || touch $OUTPUT
	truncate -s 0 $OUTPUT
	echo "**** TESTS starting on $(date)" >>$OUTPUT
	START_HASH=$(calculate_hash)

	# Run the unit tests first.
	echo "Starting unit test."
	$(which time) -o $TIME -f %E ./runtests.sh 2>&1 | tee $OUTPUT
	RET=$?
	error_count=$(cat $OUTPUT | grep "^FAILED (failures=[0-9]*)$" | wc -l)
  echo 
  echo "FAILURES:"
  echo
  cat $OUTPUT | grep "^ASSERT:.*"
  echo "Error count: " $(cat $OUTPUT | grep "^ASSERT:.*" | wc -l)
	if [ $error_count -ne 0 ] || [ "$RET" -ne 0 ]; then
		show_fail_msg "Unit"
		return
	else
		show_success_msg "Unit"
	fi
	cat $TIME
}

# Initial run of tests.
CURRENT_HASH=$(calculate_hash)
run_tests

while true; do
	if [ "$(calculate_hash)" != "$CURRENT_HASH" ]; then
		echo "Change in files detected, re-running now."
		CURRENT_HASH=$(calculate_hash)
		run_tests
	fi

	if [ "$(calculate_hash)" == "$CURRENT_HASH" ]; then
		inotifywait -r -q -e modify,move,create,delete,attrib . 
	fi
done
