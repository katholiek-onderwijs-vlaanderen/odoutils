#!/usr/bin/env bash

# e - script stops on error (return != 0)
# u - error if undefined variable
set -eu

# Version of the script
SCRIPT_VERSION=0.9

# Temp file where the output of the docker running the test suite is stored.
LOG=/tmp/odounit-odoo-container.log
# Temp file where debug tracing is written. Tail it to debug the script.
TRACE=/tmp/odoutils-trace.log

# Base names for dockers.
# The actual name incorporates a hash that is dependent on module to test, odoo version and database version.

# Base name of the docker container with odoo that runs the test suite.
DOCKER_ODOO=run-odoo-tests-odoo
# Base name of the docker container that runs the postgres that is backing the odoo instance running the test suite.
DOCKER_PG=run-odoo-tests-pg
# Base name of the user-defined bridge network that connects the odoo container with the database container.
DOCKER_NETWORK=run-odoo-tests-network

# Name of the docker image that is used to run the test suite.
DOCKER_ODOO_IMAGE_NAME=odoo:15
# Name of the docker image that is used for the backing database of the odoo instance that runs the test suite.
DOCKER_PG_IMAGE_NAME=postgres:10

# Run in loop, or run once. 0: loop / 1: once
ONCE=0
# PLAIN=0 -> Output in interactive mode with screen clear and color.
# PLAIN=1 -> Do not clear the screen, and do not use ANSI escape codes to add colors to the output.
PLAIN=0

# Did the last run of the test suite fail? 0: All tests passed, 1: At least one test failed, 2: Some other (unknown error) occured.
# -1 if test suite was not yet run.
LAST_RUN_FAILED=-1

function trace() {
	echo "$1" >>"$TRACE" 2>&1
}

function ctrl_c_once() {
	trace "Stopping odoo server"
	docker stop $DOCKER_ODOO_FULL_NAME >>$TRACE 2>&1
	trace "Stopping postgres server"
	docker stop $DOCKER_PG_FULL_NAME >>$TRACE 2>&1
	exit 0
}

function ctrl_c() {
	echo $(tput sgr 0)
	clear
	ctrl_c_once
}

function please_install {
	echo "This script requires these command to run:"
	echo
	echo " - figlet"
	echo " - tput (from package ncurses-bin)"
	echo " - docker (from docker.io)"
	echo " - inotifywait (from inotify-tools)."
	echo
	echo "Please install them."
	echo
	echo "On Ubuntu for example:"
	echo
	echo "$ sudo apt-get install figlet ncurses-bin docker.io inotify-tools"
	echo
	echo "In the above docker.io is the default docker package that is bundled with ubuntu."
	echo "If you want a more recent version please follow the instructions on the docker website."
	echo
	exit 1
}

function usage_message {
	echo "Usage: $0 [-h | -t | -r] [-p] [-o] [-g] [odoo_module_name]"
}

function help_message {
	echo "$0 is a test suite runner for odoo modules. It is designed to allow you get quick feedback on changes"
	echo "you make in the test suite or the implementation of your module."
	echo "It can be used interactively (default), in which case it will continuously monitor your sources and"
	echo "(re)run the test suite when a change is detected. A clear visual message is given when tests pass or fail."
	echo
	echo "Alternatively you can use it to run a test suite once, and check the exit code for scripting purposes in a CI/CD setup."
	echo
	echo "It uses docker containers to isolate the entire process of running the tests from the rest of your system."
	echo
	echo "Options:"
	echo
	echo "    -g    select the version of odoo to use for running the test suite. Tested with: 14,15 and 16. "
	echo
	echo "    -h    Displays this help message."
	echo
	echo "    -o    Run test suite once. Do not enter loop to re-run test suite on file change."
	echo
	echo "    -p    Do not output in color. Do not clear screen."
	echo
	echo "    -r    Delete the database and odoo containers, as well as the bridge network between them."
	echo "          The containers and network will be re-created when you run the tests next time."
	echo "          The exit code is 0, also when nothing was deleted."
	echo
	echo "    -t    Tails the output of the test run."
	echo "          You should start <$0 module_name> first, and issue $0 -t to view logs in a separate terminal session."
	echo
	echo "    -v    Displays the version of the script."
	echo
	echo
	echo "    -d    Trace the script for debugging purposes."
	echo "          Run the script itself first in a separate terminal session, then $0 -d to trace it."
	echo
	echo "Exit codes: (mostly useful in combination with --once --plain, for scripting purposes)"
	echo
	echo "    0  All tests passed."
	echo "    1  At least one test failed."
	echo "    2  An (unkown) error occured during running of the tests. (Module install failed / ...)"
	echo
	echo "Examples:"
	echo
	echo "Run the test suite of module 'my_module' in a loop and show full color output:"
	echo "$ $0 my_module"
	echo
	echo "Run the test suite for module 'my_module' once and output in plain text:"
	echo "$ $0 -p -o my_module"
	echo
	echo "Open a second terminal session, while $0 is running, and inspect the tail of the odoo log:"
	echo "$ $0 -t"
	echo
	echo "Delete all containers and log files (by default containers are created and then reused for speed):"
	echo "$ $0 -r"
}

function delete_containers {
	if [ $(docker ps -a | grep "$DOCKER_ODOO" | wc -l) -gt 0 ]; then
		trace "Deleting all odoo containers."
		docker rm -f $(docker ps -a | grep "$DOCKER_ODOO" | cut -f 1 -d ' ') >>$TRACE
	else
		trace "No odoo containers found to delete."
	fi
	if [ $(docker ps -a | grep "$DOCKER_PG" | wc -l) -gt 0 ]; then
		trace "Deleting all pg containers."
		docker rm -f $(docker ps -a | grep "$DOCKER_PG" | cut -f 1 -d ' ') >>$TRACE
	else
		trace "No pg containers found to delete."
	fi

	if [ $(docker network ls | grep "$DOCKER_NETWORK" | wc -l) -gt 0 ]; then
		trace "Deleting all networks."
		docker network rm $(docker network ls | grep "$DOCKER_NETWORK" | cut -f 1 -d ' ') >>$TRACE
	else
		trace "No bridge networks found to delete."
	fi

	trace "Truncating log and trace files."
	truncate $LOG >>$TRACE 2>&1
	trace "truncating trace files. BYE BYE! :)"
	truncate $TRACE >/dev/null 2>&1
}

function run_tests {
	trace "run_tests starting."
	timestamp=$(date --rfc-3339=seconds | sed "s/ /T/")
	trace "Timestamp when we are running: $timestamp"

	trace "(Re)starting the odoo server to run the test suite."
	docker restart $DOCKER_ODOO_FULL_NAME >>$TRACE 2>&1
	docker logs -f --since $timestamp $DOCKER_ODOO_FULL_NAME 2>$LOG
	trace "Server finisfed running the odoo test suite."

	if [ $(cat "$LOG" | grep ".* ERROR odoo .*test.*FAIL:" | wc -l) -ne 0 ]; then
		LAST_RUN_FAILED=1

		if [ "$PLAIN" -eq 0 ]; then
			echo -n "$(tput bold)$(tput setaf 7)$(tput setab 1)"
			clear
		fi

		trace "Displaying FAILED message."
		figlet -c -t "FAILED!" 2>>$TRACE
		echo

		trace "Displaying list of failed tests."

		if [ "$PLAIN" -eq 0 ]; then
			echo "$(tput smso)These tests failed:$(tput rmso)"
		else
			echo "These tests failed:"
		fi
		cat "$LOG" | grep ".* ERROR odoo .*test.*FAIL:" | sed 's/.*FAIL: //g' | cut -c -$(tput cols)
		echo

		error_count=$(cat "$LOG" | grep ".* ERROR odoo .*test.*FAIL:" | wc -l)
		trace "Counted $error_count errors in the odoo logs."

		lines=$(expr $(tput lines) - 11 - $error_count)
		trace "Number of lines to tail on the rest of the screen: $lines"

		trace "Logging stack traces of failures from logs."
		if [ "$PLAIN" -eq 0 ]; then
			echo "$(tput smso)Traces of the first failures:$(tput rmso)"
		else
			echo "Traces of the first failures:"
		fi
		cat "$LOG" | sed -n '/.*FAIL: /,/.*INFO /p' | head -n $lines | cut -c -$(tput cols)
		trace "Finished logging of stack traces for failures."
	elif [ $(cat $LOG | grep '.* ERROR odoo .*' | wc -l) -ne 0 ]; then
		LAST_RUN_FAILED=2

		trace "Errors other than FAIL detected.."

		if [ "$PLAIN" -eq 0 ]; then
			echo -n "$(tput bold)$(tput setaf 7)$(tput setab 4)"
			clear
		fi

		figlet -c -t "Unknown" 2>>$TRACE
		echo

		lines=$(expr $(tput lines) - 9)
		trace "Number of lines to tail on the rest of the screen: $lines"

		trace "Showing tail of odoo log on screen."

		if [ "$PLAIN" -eq 0 ]; then
			echo "$(tput smso)Tail of logs:$(tput rmso)"
		else
			echo "Tail of logs:"
		fi

		tail -n $lines "$LOG" | cut -c -$(tput cols)
	else
		LAST_RUN_FAILED=0
		if [ "$PLAIN" -eq 0 ]; then
			echo -n "$(tput bold)$(tput setaf 7)$(tput setab 2)"
			clear
		fi

		trace "Displaying SUCCESS message."
		figlet -c -t "Success" 2>>$TRACE
		echo

		lines=$(expr $(tput lines) - 9)
		trace "Number of lines to tail on the rest of the screen: $lines"

		echo "Showing tail of odoo log on screen." >>$TRACE
		if [ "$PLAIN" -eq 0 ]; then
			echo "$(tput smso)Tail of logs:$(tput rmso)"
		else
			echo "Tail of logs:"
		fi
		tail -n $lines "$LOG" | cut -c -$(tput cols)
	fi
	trace "run_tests ended."
}

trace "*** Script starting..."

# Check if all dependencies are installed..
trace "Verifying that figlet is installed."
command -v figlet >>$TRACE 2>&1 || please_install figlet figlet
trace "Verifying that docker is installed."
command -v docker >>$TRACE 2>&1 || please_install docker docker.io
trace "Verifying that tput is installed."
command -v tput >>$TRACE 2>&1 || please_install tput ncurses-bin
trace "Verifying that inotifywait is installed."
command -v inotifywait >>$TRACE 2>&1 || please_install inotifywait inotify-tools

# If we are running on WSL, check that the docker command
trace "Verifying that docker command is available."
# is telling us to start the docker engine via the UI...
if [ $(docker 2>&1 | grep "could not be found" | wc -l) -ne 0 ]; then
	docker
	echo
	echo "***************************************************************************"
	echo "*** Please make sure the docker engine is started using docker desktop. ***"
	echo "***************************************************************************"
	echo
	exit 2
fi

if [ $(docker ps 2>&1 | grep "Cannot connect to" | wc -l) -ne 0 ]; then
	echo
	echo "***************************************************************************"
	echo "*** Please make sure the docker engine is started using docker desktop. ***"
	echo "***************************************************************************"
	echo
	exit 2
fi

trace "Starting parse of command line."

while getopts "dg:hoprtv" opt; do
	trace "Parsing option [$opt] now:"
	case $opt in
	d)
		touch "$TRACE"
		tail -f "$TRACE"
		exit 0
		;;

	g)
		trace "-g detected"
		VERSION=$OPTARG
		DOCKER_ODOO_IMAGE_NAME=odoo:$VERSION
		case $VERSION in
		13 | 14 | 15)
			DOCKER_PG_IMAGE_NAME=postgres:10
			;;
		16)
			DOCKER_PG_IMAGE_NAME=postgres:12
			;;
		esac
		trace "Will use DOCKER_ODOO_IMAGE_NAME [$DOCKER_ODOO_IMAGE_NAME] and DOCKER_PG_IMAGE_NAME [$DOCKER_PG_IMAGE_NAME]."
		;;

	h)
		trace "-h detected -> Showing help message."
		usage_message
		echo
		help_message
		echo
		exit 0
		;;
	o)
		trace "-o detected."
		ONCE=1
		;;

	p)
		trace "-p detected. Setting PLAIN=1."
		PLAIN=1
		;;

	r)
		trace "-r detected. deleting conatiner + networks."
		echo "Removing postgres and odoo containers used for running tests."
		echo "They will be created automatically again when you run $0."
		delete_containers
		echo "Done."
		exit 0
		;;

	t)
		if [ -s $LOG ]; then
			trace "-t detected. Starting tail -f on odoo container log."
			tail -f $LOG
		else
			trace "-t detected, but no log file found. Showing tip to user."
			echo "Please start $0 [module_name] first in a different console, then issue this command to tail the logs."
		fi
		;;

	v)
		echo "Script version: $SCRIPT_VERSION"
		exit 0
		;;
	esac
done

trace "Shifting arguments to find module name."
trace "Command line = [$@]."
shift $(($OPTIND - 1))

# Check that the user specified a module to test.
if [ -z ${1+x} ]; then
	echo "No module to test was specified."
	echo
	usage_message
	exit 2
fi

MODULE=$(echo "$1" | sed 's/\///g')
trace "Module to test: [$MODULE]."

if [ ! -d "$MODULE" ]; then
	echo "Module [$1] is not a folder in the current working directory [$(pwd)]."
	echo
	echo "Please specify a valid odoo module."
	exit 2
fi
trace "Finished parsing of command line."

# Log all variables for debugging purposes.
trace "Current DOCKER_ODOO_IMAGE_NAME=$DOCKER_ODOO_IMAGE_NAME"
trace "Current DOCKER_PG_IMAGE_NAME=$DOCKER_PG_IMAGE_NAME"
trace "Current DOCKER_NETWORK=$DOCKER_NETWORK"

# Calculate full names for containers and network bridge
DOCKER_HASH=$(echo "$MODULE" "$DOCKER_ODOO_IMAGE_NAME" "$DOCKER_PG_IMAGE_NAME" | md5sum | cut -d ' ' -f1)
DOCKER_NETWORK_FULL_NAME="$DOCKER_NETWORK-$DOCKER_HASH"
DOCKER_PG_FULL_NAME="$DOCKER_PG-$DOCKER_HASH"
DOCKER_ODOO_FULL_NAME="$DOCKER_ODOO-$DOCKER_HASH"
trace "DOCKER_HASH=$DOCKER_HASH"
trace "DOCKER_NETWORK_FULL_NAME=$DOCKER_NETWORK_FULL_NAME"
trace "DOCKER_PG_FULL_NAME=$DOCKER_PG_FULL_NAME"
trace "DOCKER_ODOO_FULL_NAME=$DOCKER_ODOO_FULL_NAME"

trace "PLAIN=$PLAIN"
trace "ONCE=$ONCE"

echo "Checking if the user-defined bridge network exists." >>$TRACE
if [ $(docker network ls | grep "$DOCKER_NETWORK_FULL_NAME" | wc -l) -eq 0 ]; then
	trace "Creating the user-defined bridge network."
	docker network create "$DOCKER_NETWORK_FULL_NAME" >>$TRACE 2>&1
else
	trace "User defined bridge network $DOCKER_NETWORK_FULL_NAME still exists, re-using it."
fi

trace "Checking if the postgres docker [$DOCKER_PG_FULL_NAME] exists."
if [ $(docker ps -a | grep "$DOCKER_PG_FULL_NAME" | wc -l) -eq 0 ]; then
	trace "Creating a postgres server."
	docker create -e POSTGRES_USER=odoo -e POSTGRES_PASSWORD=odoo -e POSTGRES_DB=postgres --network "$DOCKER_NETWORK_FULL_NAME" --name "$DOCKER_PG_FULL_NAME" "$DOCKER_PG_IMAGE_NAME" >>$TRACE 2>&1
else
	trace "Docker $DOCKER_PG_FULL_NAME still exists, re-using it."
fi

trace "Checking if the odoo docker exists."
if [ $(docker ps -a | grep "$DOCKER_ODOO_FULL_NAME" | wc -l) -eq 0 ]; then
	trace "Creating the odoo server to run the tests."
	docker create -v $(pwd):/mnt/extra-addons --name "$DOCKER_ODOO_FULL_NAME" --network "$DOCKER_NETWORK_FULL_NAME" -e HOST="$DOCKER_PG_FULL_NAME" "$DOCKER_ODOO_IMAGE_NAME" -d odoo -u "$MODULE" -i "$MODULE" --stop-after-init --without-demo all --test-tags "/$MODULE" >>$TRACE 2>&1
else
	trace "Docker $DOCKER_ODOO_FULL_NAME still exists, re-using it."
fi

# Make sure database is started.
trace "Starting the postgres server."
docker start $DOCKER_PG_FULL_NAME >>$TRACE 2>&1

if [ "$ONCE" -eq 0 ]; then
	# Set handling of CTRL-C to allow the user to stop the loop.
	trap ctrl_c INT

	while true; do
		hash=$(find "$MODULE" -type f -exec ls -l --full-time {} + | sort | md5sum)
		trace "Calculated hash for the folder where we are running AT START OF CYCLE: $hash"

		run_tests

		trace "Calculating hash of the filer now."
		hash2=$(find "$MODULE" -type f -exec ls -l --full-time {} + | sort | md5sum)
		trace "Calculated hash of the folder where we are running AT END OF CYCLE: $hash2"
		while [ "$hash" = "$hash2" ]; do
			inotifywait -r -q "$MODULE" >>$TRACE 2>&1
			hash2=$(find "$MODULE" -type f -exec ls -l --full-time {} + | sort | md5sum)
			trace "Calculated hash of the folder after inotifywait: $hash2"
			trace "Watching [$(pwd)/$MODULE]"
		done
	done
else
	# Set handling of CTRL-C to allow the user to stop the loop.
	trap ctrl_c_once INT
	run_tests
	exit $LAST_RUN_FAILED
fi
