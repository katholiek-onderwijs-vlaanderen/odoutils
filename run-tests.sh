#!/bin/bash
ERRORS=/tmp/run-tests-errors.txt
LOG=/tmp/run-tests-logs.txt
TRACE=/tmp/run-tests-trace.txt
DOCKER_ODOO=om-hospital-test-odoo
DOCKER_PG=om-hospital-test-pg

#default values for configuration file
DOCKER_ODOO_IMAGE_NAME=odoo:15
DOCKER_PG_IMAGE_NAME=postgres:10

trap ctrl_c INT
function remove_temp_files {
	# Clean up temporary files
	rm $ERRORS 2 &>1 >>$TRACE
	rm $LOG 2 &>1 >>$TRACE
	if [ -f $TRACE ]; then
		rm $TRACE 2 &>1 >/dev/null
	fi
}

function ctrl_c() {
	echo $(tput sgr 0)
	clear
	echo "Stopping odoo server" >>$TRACE
	docker stop $DOCKER_ODOO >>$TRACE
	echo "Stopping postgres server" >>$TRACE
	docker stop $DOCKER_PG >>$TRACE
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
	echo "Usage: ./run-tests.sh [--configure | --help] [odoo_module_name]"
}

function help_message {
	echo "Use --configure to set the odoo version and postgres version to use for running the test suite."
	echo ""
	echo "Specify the odoo module folder to run the test suite:"
	echo
	echo "$ ./run-tests.sh my_module"
	echo
}

# Remove any old files
remove_temp_files

# Check if all dependencies are installed..
command -v figlet >>$TRACE || please_install figlet figlet
command -v docker >>$TRACE || please_install docker docker.io
command -v tput >>$TRACE || please_install tput tput
command -v inotifywait >>$TRACE || please_install inotifywait inotify-tools

# If we are running on WSL, check that the docker command
# is telling us to start the docker engine via the UI...
docker 2 &>1 >/tmp/docker.log
not_found=$(cat /tmp/docker.log | grep "could not be found" | wc -l)
if [ $not_found -ne 0 ]; then
	cat /tmp/docker.log
	echo
	echo "***************************************************************************"
	echo "*** Please make sure the docker engine is started using docker desktop. ***"
	echo "***************************************************************************"
	exit 1
fi

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
	exit 1
fi
MODULE=$1

if [ -f .run-odoo-tests/config ]; then
	echo "Found configuration file, and sourcing it." >>$TRACE
	source .run-odoo-tests/config
else
	echo "Configuration missing, continuing with defaults" >>$TRACE
fi
echo "Current DOCKER_ODOO_IMAGE_NAME=$DOCKER_ODOO_IMAGE_NAME" >>$TRACE
echo "Current DOCKER_PG_IMAGE_NAME=$DOCKER_PG_IMAGE_NAME" >>$TRACE

echo "Checking if the postgres docker exists." >>$TRACE
found_docker_pg=$(docker ps -a | grep $DOCKER_PG | wc -l)
if [ $found_docker_pg -eq 0 ]; then
	echo "Creating a postgres server." >>$TRACE
	docker create -p 5433:5432 -e POSTGRES_USER=odoo -e POSTGRES_PASSWORD=odoo -e POSTGRES_DB=postgres --name $DOCKER_PG $DOCKER_PG_IMAGE_NAME >>$TRACE
fi

echo "Checking if the odoo docker exists." >>$TRACE
found_docker_odoo=$(docker ps -a | grep $DOCKER_ODOO | wc -l)
if [ $found_docker_odoo -eq 0 ]; then
	echo "Creating the odoo server to run the tests." >>$TRACE
	docker create -v ~/prj:/mnt/extra-addons -p 8071:8069 --name $DOCKER_ODOO --link $DOCKER_PG:db $DOCKER_ODOO_IMAGE_NAME -d odoo -u om_hospital -i om_hospital --stop-after-init --test-tags /om_hospital >>$TRACE
fi

# Make sure database is started.
echo "Starting the postgres server." >>$TRACE
docker start $DOCKER_PG >>$TRACE

while true; do
	hash=$(find "$MODULE" -type f -exec ls -l {} + | sort | md5sum)
	echo "Calculated hash for the folder where we are running AT START OF CYCLE: $hash" >>$TRACE

	timestamp=$(date --rfc-3339=seconds | sed "s/ /T/")
	echo "Timestamp when we are running: $timestamp" >>$TRACE

	echo "(Re)starting the odoo server to run the test suite." >>$TRACE
	docker restart $DOCKER_ODOO >>$TRACE
	docker logs -f --since $timestamp $DOCKER_ODOO 2>$LOG
	echo "Finished running the tests..." >>$TRACE

	echo "Server finised running the odoo test suite." >>$TRACE
	cat $LOG | grep "ERROR.*test.*FAIL:" >$ERRORS
	if [ -s $ERRORS ]; then
		echo -n "$(tput bold)$(tput setaf 7)$(tput setab 1)"
		clear

		echo "Displaying FAILED message." >>$TRACE
		figlet -c -t "*** FAILED! ***"
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

		#		echo "Showing tail of odoo logs on screen." >>$TRACE
		#		echo "$(tput smso)Logs of the odoo server:$(tput rmso)"
		#		tail -n $lines $LOG | cut -c -$(tput cols)
	else
		echo -n "$(tput bold)$(tput setaf 7)$(tput setab 2)"
		clear

		echo "Displaying SUCCESS message." >>$TRACE
		figlet -c -t "*** SUCCESS ***"
		echo

		echo "Number of lines to tail on the rest of the screen: $lines" >>$TRACE
		lines=$(expr $(tput lines) - 8)

		echo "Showing tail of odoo log on screen." >>$TRACE
		tail -n $lines $LOG | cut -c -$(tput cols)
	fi

	hash2=$(find "$MODULE" -type f -exec ls -l {} + | sort | md5sum)
	echo "Calculated hash of the folder where we are running AT END OF CYCLE: $hash2" >>$TRACE
	if [ "$hash" = "$hash2" ]; then
		echo "Waiting for changes on the filesystem." >>$TRACE
		inotifywait -r -q "$MODULE" 2>&1 >>$TRACE
	fi
done
