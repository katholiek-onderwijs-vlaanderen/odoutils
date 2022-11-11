#!/bin/bash

# Default values for variables
# Can be overridden via .run-odoo-tests/config, or using command line parameters (TO DO: add support).

# Temp file where the detected FAILs are stored.
ERRORS=/tmp/run-tests-errors.txt
# Temp file where the output of the docker running the test suite is stored.
LOG=/tmp/run-tests-logs.txt
# Temp file where debug tracing is written. Tail it to debug the script.
TRACE=/tmp/run-tests-trace.txt
# Name of the docker container with odoo that runs the test suite.
DOCKER_ODOO=run-odoo-tests-odoo
# Name of the docker container that runs the postgres that is backing the odoo instance running the test suite.
DOCKER_PG=run-odoo-tests-pg
# Name of the docker image that is used to run the test suite.
DOCKER_ODOO_IMAGE_NAME=odoo:15
# Name of the docker image that is used for the backing database of the odoo instance that runs the test suite.
DOCKER_PG_IMAGE_NAME=postgres:10
# Name of the user-defined bridge network that connects the odoo container with the database container.
DOCKER_NETWOR=run-odoo-tests-network

function remove_temp_files {
	# Clean up temporary files
	rm $ERRORS >>$TRACE 2>&1
	rm $LOG >>$TRACE 2>&1
	if [ -f $TRACE ]; then
		rm $TRACE >/dev/null 2>&1
	fi
}

function ctrl_c() {
	echo $(tput sgr 0)
	clear
	echo "Stopping odoo server" >>$TRACE
	docker stop $DOCKER_ODOO >>$TRACE 2>&1
	echo "Stopping postgres server" >>$TRACE
	docker stop $DOCKER_PG >>$TRACE 2>&1
	exit 0
}

function please_install {
	echo "This script requires the <$1> command. Please install it."
	echo
	echo "On Ubuntu for example:"
	echo
	echo "$ sudo apt-get install $2"
	exit 1
}

function usage_message {
	echo "Usage: ./run-tests.sh [--configure | --help | --tail] [odoo_module_name]"
}

function help_message {
	echo "Specify the odoo module folder to run the test suite:"
	echo
	echo "$ ./run-tests.sh my_module"
	echo
	echo "Options:"
	echo
	echo "    --configure    Prompts for configuration of the odoo version and postgres version to use for running the test suite."
	echo
	echo "    --tail         Tails the output of the test run."
	echo "                   You should start <run-test.sh module_name> first, and issue run-test.sh --tail to view logs."
	echo
	echo "    --remove       Delete the database and odoo container, as well as the bridge network between them."
	echo "                   The containers and network will be re-created when you run the tests next time."
	echo "                   The exit code is 0, also when nothing needed to be / was deleted."
	echo
	echo "    --help         Displays this help message."
	echo 
	echo "Exit codes: (mostly useful in combination with --once)"
	echo
	echo "    0  All tests were run, and none of them failed."
	echo "    1  All tests were run, and at least one of them failed."
	echo "    2  A different (unkown) error occured during the execution of the script / running of the tests."
}

function delete_containers {
	docker rm -f "$DOCKER_ODOO"
	docker rm -f "$DOCKER_PG"
	docker network rm "$DOCKER_NETWORK"
}

# Check if all dependencies are installed..
command -v figlet >>$TRACE || please_install figlet figlet
command -v docker >>$TRACE || please_install docker docker.io
command -v tput >>$TRACE || please_install tput tput
command -v inotifywait >>$TRACE || please_install inotifywait inotify-tools

# If we are running on WSL, check that the docker command
# is telling us to start the docker engine via the UI...
docker >/tmp/docker.log 2>&1
not_found=$(cat /tmp/docker.log | grep "could not be found" | wc -l)
if [ $not_found -ne 0 ]; then
	cat /tmp/docker.log
	echo
	echo "***************************************************************************"
	echo "*** Please make sure the docker engine is started using docker desktop. ***"
	echo "***************************************************************************"
	exit 1
fi

# Load configuration file first (before processing of command line arguments)
if [ -f .run-odoo-tests/config ]; then
	echo "Found configuration file, and sourcing it." >>$TRACE
	source .run-odoo-tests/config
else
	echo "Configuration missing, continuing with defaults." >>$TRACE
fi

# Process the command line arguments.
if [ $# -ne 1 ]; then
	usage_message
	exit 1
elif [ "$1" = "--configure" ]; then
	echo "Starting configuration flow." >>$TRACE
	echo "TO DO: Implement configuration flow"
	exit 1
elif [ "$1" = "--help" ]; then
	echo "Showing help message." >>$TRACE
	usage_message
	echo
	help_message
	echo
	exit 1
elif [ "$1" = "--tail" ]; then
	if [ -s $LOG ]; then
		tail -f $LOG
	else
		echo "Please start ./run-tests.sh [module_name] first in a different console, then issue this command to tail the logs."
	fi
	exit 0
elif [ "$1" = "--remove" ]; then
	echo "Removing postgres and odoo containers used for running tests."
	echo "They will be created automatically again when you run ./run-tests.sh."
	delete_containers
	echo "Done."
	exit 0
fi
MODULE=$1

echo "Current DOCKER_ODOO_IMAGE_NAME=$DOCKER_ODOO_IMAGE_NAME" >>$TRACE
echo "Current DOCKER_PG_IMAGE_NAME=$DOCKER_PG_IMAGE_NAME" >>$TRACE
echo "Current DOCKER_NETWORK=$DOCKER_NETWORK" >>$TRACE

echo "Checking if the user-defined bridge network exists." >>$TRACE
if [ $(docker network ls | grep "$DOCKER_NETWORK" | wc -l) -eq 0 ]; then
	echo "Creating the user-defined bridge network." >>$TRACE
	docker network create "$DOCKER_NETWORK" >>$TRACE 2>&1
fi

echo "Checking if the postgres docker exists." >>$TRACE
found_docker_pg=$(docker ps -a | grep $DOCKER_PG | wc -l)
if [ $found_docker_pg -eq 0 ]; then
	echo "Creating a postgres server." >>$TRACE
	docker create -e POSTGRES_USER=odoo -e POSTGRES_PASSWORD=odoo -e POSTGRES_DB=postgres --network "$DOCKER_NETWORK" --name "$DOCKER_PG" "$DOCKER_PG_IMAGE_NAME" >>$TRACE 2>&1
fi

echo "Checking if the odoo docker exists." >>$TRACE
found_docker_odoo=$(docker ps -a | grep $DOCKER_ODOO | wc -l)
if [ $found_docker_odoo -eq 0 ]; then
	echo "Creating the odoo server to run the tests." >>$TRACE
	docker create -v ~/prj:/mnt/extra-addons --name "$DOCKER_ODOO" --network "$DOCKER_NETWORK" -e HOST=$DOCKER_PG "$DOCKER_ODOO_IMAGE_NAME" -d odoo -u "$MODULE" -i "$MODULE" --stop-after-init --test-tags "/$MODULE" >>$TRACE 2>&1
fi

# Remove any old files
remove_temp_files

# Set handling of CTRL-C to allow the user to stop the loop.
trap ctrl_c INT

# Make sure database is started.
echo "Starting the postgres server." >>$TRACE
docker start $DOCKER_PG >>$TRACE 2>&1

while true; do
	hash=$(find "$MODULE" -type f -exec ls -l {} + | sort | md5sum)
	echo "Calculated hash for the folder where we are running AT START OF CYCLE: $hash" >>$TRACE

	timestamp=$(date --rfc-3339=seconds | sed "s/ /T/")
	echo "Timestamp when we are running: $timestamp" >>$TRACE

	echo "(Re)starting the odoo server to run the test suite." >>$TRACE
	docker restart $DOCKER_ODOO >>$TRACE 2>&1
	docker logs -f --since $timestamp $DOCKER_ODOO 2>$LOG
	echo "Finished running the tests..." >>$TRACE

	echo "Server finised running the odoo test suite." >>$TRACE
	cat $LOG | grep ".* ERROR odoo .*test.*FAIL:" >$ERRORS

	if [ -s $ERRORS ]; then
		echo -n "$(tput bold)$(tput setaf 7)$(tput setab 1)"
		clear

		echo "Displaying FAILED message." >>$TRACE
		figlet -c -t "FAILED!" 2>>$TRACE
		echo

		echo "Displaying list of failed tests." >>$TRACE
		echo "$(tput smso)These tests failed:$(tput rmso)"
		cat $ERRORS | sed 's/.*FAIL: //g' | cut -c -$(tput cols)
		echo

		error_count=$(cat $ERRORS | wc -l)
		echo "Counted $error_count errors in the odoo logs." >>$TRACE

		lines=$(expr $(tput lines) - 11 - $error_count)
		echo "Number of lines to tail on the rest of the screen: $lines" >>$TRACE

		echo "Logging stack traces of failures from logs." >>$TRACE
		echo "$(tput smso)Traces of the first failures:$(tput rmso)"
		cat /tmp/run-tests-logs.txt | sed -n '/.*FAIL: /,/.*INFO /p' | head -n $lines | cut -c -$(tput cols)
	elif [ $(cat $LOG | grep '.* ERROR odoo .*' | wc -l) -ne 0 ]; then
		echo "Errors other than FAIL detected.." >>$TRACE
		echo -n "$(tput bold)$(tput setaf 7)$(tput setab 4)"
		clear
		figlet -c -t "Unknown" 2>>$TRACE
		echo

		echo "Number of lines to tail on the rest of the screen: $lines" >>$TRACE
		lines=$(expr $(tput lines) - 9)

		echo "Showing tail of odoo log on screen." >>$TRACE
		echo "$(tput smso)Tail of logs:$(tput rmso)"
		tail -n $lines $LOG | cut -c -$(tput cols)
	else
		echo -n "$(tput bold)$(tput setaf 7)$(tput setab 2)"
		clear

		echo "Displaying SUCCESS message." >>$TRACE
		figlet -c -t "Success" 2>>$TRACE
		echo

		echo "Number of lines to tail on the rest of the screen: $lines" >>$TRACE
		lines=$(expr $(tput lines) - 9)

		echo "Showing tail of odoo log on screen." >>$TRACE
		echo "$(tput smso)Tail of logs:$(tput rmso)"
		tail -n $lines $LOG | cut -c -$(tput cols)
	fi

	hash2=$(find "$MODULE" -type f -exec ls -l {} + | sort | md5sum)
	echo "Calculated hash of the folder where we are running AT END OF CYCLE: $hash2" >>$TRACE
	if [ "$hash" = "$hash2" ]; then
		echo "Waiting for changes on the filesystem." >>$TRACE
		inotifywait -r -q "$MODULE" >>$TRACE 2>&1
	fi
done
