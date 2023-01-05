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
	echo "Usage: $0 [-h | -t | -r] [-i modules_to_install] [-p] [-o] [-g] module_to_test1 [module_to_test_2]"
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
  echo "    -t    Specify the tests to run (default is all tests in all installed modules) manually. "
  echo "          Uses the same syntax as --test-tags in odoo command line."
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
	echo "Delete all containers and log files (by default containers are created and then reused for speed):"
	echo "$ $0 -r"
	echo
  echo "Run test suite for module_A and module_B (both modules will be installed and tests for both will be run):"
	echo "$ $0 module_A module_B"
}

# Output big text with figlet
# Fixes issue with background color sequence not getting applied correctly.
# First clear to end of line for 6 line, then re-positiotn cursor back up, then output figlet.
# $1 message to display
function big_text {
  if [ "$PLAIN" -eq 0 ]; then
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
  else
    echo "$1"
  fi
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
  if [ $PLAIN -eq 0 ]; then
    docker start -i $DOCKER_ODOO_FULL_NAME 2>&1 | tee "$LOG"
  else
    docker start -i $DOCKER_ODOO_FULL_NAME 2>&1 | sed 's/\x1b\[[0-9;]*[mGKHF]//g' | tee "$LOG"
  fi
	#docker logs -f --since $timestamp $DOCKER_ODOO_FULL_NAME 2>&1 | tee "$LOG"
	trace "Server finished running the odoo test suite."

	if [ $(cat "$LOG" | grep "ERROR.* odoo .*test.*FAIL:" | wc -l) -ne 0 ]; then
		LAST_RUN_FAILED=1

		if [ "$PLAIN" -eq 0 ]; then
			echo -n "$(tput bold)$(tput setaf 7)$(tput setab 1)"
		fi

		trace "Displaying FAILED message."
    big_text "FAILED!"

		trace "Displaying list of failed tests."

		if [ "$PLAIN" -eq 0 ]; then
			echo "$(tput smso)These tests failed:$(tput rmso)"
		else
			echo "These tests failed:"
		fi
		cat "$LOG" | grep "ERROR.*odoo.*test.*FAIL:" | sed 's/.*FAIL: //g' | cut -c -$(tput cols)

		error_count=$(cat "$LOG" | grep "ERROR.* odoo .*test.*FAIL:" | wc -l)
		trace "Counted $error_count errors in the odoo logs."

		[ "$PLAIN" -eq 0 ] && echo "$(tput sgr0)"

	elif [ $(cat $LOG | grep 'ERROR.* odoo .*' | wc -l) -ne 0 ]; then
		LAST_RUN_FAILED=2

		trace "Errors other than FAIL detected.."

		if [ "$PLAIN" -eq 0 ]; then
			echo -n "$(tput bold)$(tput setaf 7)$(tput setab 4)"
		fi

    big_text "Unknown"

		[ "$PLAIN" -eq 0 ] && echo "$(tput sgr0)"

	else
		LAST_RUN_FAILED=0
		if [ "$PLAIN" -eq 0 ]; then
			echo -n "$(tput bold)$(tput setaf 7)$(tput setab 2)"
		fi

		trace "Displaying SUCCESS message."
    big_text "Success"

		[ "$PLAIN" -eq 0 ] && echo "$(tput sgr0)"

	fi
	trace "run_tests ended."
}

# Check that $@ has one or more modules to test.
# Also validate that these modules exist in the CWD (hcurrent working directory).
# Will remove any trailing / as a convenience feature. Auto-completion in bash of a folder adds /.
#
# $@ the remaining command line arguments, after parsing (and thus removal of) flags and their arguments.
#
# echoes a comma-separated list of modules to install and test.
function parse_cmd_line_arguments() {
  RET=""

  trace "Parsing [" $# "] command line arguments."
  for m in $@; do
    trace "Removing any trailing / if present for ["$m"]"
    m=$(echo "$m" | sed 's/\///g')

    if [ -z "$RET" ]; then
      RET="$m"
    else
      RET="${RET},${m}"
    fi
  done

  trace "Generated comma-separated list of modules to install ["$RET"]"
  echo "$RET"
}

# Takes a comma-seperated list of modules, and converts it into a set of test tags for odoo
# e.g. modA,modB -> /modA,/modB
#
# $1 comma-seperated list of modules.
#
# echoes test tags back.
function create_test_tags_from_modules() {
  trace "Converting modules list ["$1"] into testing tags."
  RET=""

  modules=$(echo "$1" | sed "s/,/\n/g")
  trace "Converted comma-separated into space-separated: ["$modules"]"
  for module in $modules; do
    if [ -z "$RET" ]; then
      RET="/${module}"
    else
      RET="$RET,/${module}"
    fi
  done

  trace "Final list of test tags: ["$RET"]"
  echo "$RET"
}

# Function to calculate the hash of the watched files and folders for restarting.
#
# echoes back a hash value.
function calculate_hash() {
		echo $(find "$@" -type f -exec ls -l --full-time {} + | sort | md5sum)
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

while getopts "dg:hoprt:v" opt; do
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
		TEST_TAGS=$OPTARG
    trace "Will run with --test-tags $TEST_TAGS"
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

if [ $# -eq 0 ]; then
  echo "No module to test was specified."
  echo
  usage_message
  exit 2
fi

for m in $@; do
  trace "Removing any trailing / if present for ["$m"]"
  m=$(echo "$m" | sed 's/\///g')

  trace "Validating that ["$m"] is a valid directory in CWD."
  if [ ! -d "$m" ]; then
    echo "ERROR: Module [$m] is not a folder in the current working directory [$(pwd)]."
    echo
    echo "Please specify a valid odoo module."
    exit 2
  fi
done

# Parse command line argument, validate and convert into comma-separated list of modules to install and test.
MODULES=$(parse_cmd_line_arguments $@)

# Convert list of modules into a set of odoo testing tags.
if [ -z "${TEST_TAGS:-}" ]; then
  echo "Will run all tests in installed modules [$MODULES]."
  TEST_TAGS=$(create_test_tags_from_modules "$MODULES")
else
  echo "Will run with custom --test-tags $TEST_TAGS."
fi

trace "Finished parsing of command line."

# Log all variables for debugging purposes.
trace "Current DOCKER_ODOO_IMAGE_NAME=$DOCKER_ODOO_IMAGE_NAME"
trace "Current DOCKER_PG_IMAGE_NAME=$DOCKER_PG_IMAGE_NAME"
trace "Current DOCKER_NETWORK=$DOCKER_NETWORK"

# Calculate full names for containers and network bridge
DOCKER_HASH=$(echo "$MODULES" "$TEST_TAGS" "$DOCKER_ODOO_IMAGE_NAME" "$DOCKER_PG_IMAGE_NAME" | md5sum | cut -d ' ' -f1)
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
  command="docker create -v $(pwd):/mnt/extra-addons --name $DOCKER_ODOO_FULL_NAME --network $DOCKER_NETWORK_FULL_NAME -e HOST=$DOCKER_PG_FULL_NAME --tty --interactive $DOCKER_ODOO_IMAGE_NAME --limit-time-real 1800 --limit-time-cpu 1800 -d odoo -u $MODULES -i $MODULES --stop-after-init --without-demo all --test-tags $TEST_TAGS" 
  echo "$command"
	$command
else
	trace "Docker $DOCKER_ODOO_FULL_NAME still exists, re-using it."
fi

# Make sure database is started.
trace "Starting the postgres server."
docker start $DOCKER_PG_FULL_NAME >>$TRACE 2>&1

if [ "$ONCE" -eq 0 ]; then
	# Set handling of CTRL-C to allow the user to stop the loop.
	trap ctrl_c INT

  CURRENT_HASH=$(calculate_hash)
  run_tests

	while true; do
    if [ "$(calculate_hash)" != "$CURRENT_HASH" ]; then
      CURRENT_HASH=$(calculate_hash)
      run_tests
    fi

    if [ "$(calculate_hash)" == "$CURRENT_HASH" ]; then
			inotifywait -r -q -e modify,move,create,delete,attrib . 
    fi
	done
else
	# Set handling of CTRL-C to allow the user to stop the loop.
	trap ctrl_c_once INT
	run_tests
	exit $LAST_RUN_FAILED
fi
