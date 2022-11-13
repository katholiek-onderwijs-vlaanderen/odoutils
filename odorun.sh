#!/usr/bin/env bash

# e - script stops on error (return != 0)
# u - error if undefined variable
# o pipefail - script fails if one of the piped commands fails
# x - output each line for debugging purposes.
set -euo pipefail
#set -x

# Version of the script
SCRIPT_VERSION=0.1

# Temp file where debug tracing is written. Tail it to debug the script.
TRACE=/tmp/odorun-trace.log

# Base names for dockers.
# The actual name incorporates a hash that is dependent on module to test, odoo version and database version.

# Base name of the docker container with odoo that runs the test suite.
DOCKER_ODOO=odorun-odoo
# Base name of the docker container that runs the postgres that is backing the odoo instance running the test suite.
DOCKER_PG=odorun-pg
# Base name of the user-defined bridge network that connects the odoo container with the database container.
DOCKER_NETWORK=odorun-network

# Name of the docker image that is used to run the test suite.
DOCKER_ODOO_IMAGE_NAME=odoo:15
# Name of the docker image that is used for the backing database of the odoo instance that runs the test suite.
DOCKER_PG_IMAGE_NAME=postgres:10

# If the container should be run in development mode this flag will be set to 1.
DEV_MODE=0

# On what port on the host machine will the http port be mapped? Default: 8069. 
# Can be overridden using the -p flag.
PORT=8069

function trace() {
	echo "$1" >>"$TRACE" 2>&1
}

function please_install {
	echo "This script requires these command to run:"
	echo
	echo " - docker (from docker.io)"
	echo
	echo "Please install it."
	echo
	echo "On Ubuntu for example:"
	echo
	echo "$ sudo apt-get install docker.io"
	echo
	echo "In the above docker.io is the default docker package that is bundled with ubuntu."
	echo "If you want a more recent version please follow the instructions on the docker website."
	echo
	exit 1
}

function usage_message {
	echo "Usage: $0 [-h | -t | -r] [-p] [-o] [odoo_module_name]"
}

function help_message {
	echo "$0 is utility to easily run odoo modules in a docker container."
	echo "It uses docker containers to isolate the entire process of running the tests from the rest of your system."
	echo "It supports running in dev mode where changes to xml and/or python source files are automatically "
	echo "read / reloaded. No need for manually restarting the server."
	echo
	echo "Options:"
	echo
	echo "    -d    Start in development mode. This will append --dev xml,reload to the odoo-bin command."
	echo
	echo "    -g    Selects the odoo version to run. Tested with: 14,15 and 16."
	echo
	echo "    -h    Displays this help message."
	echo
	echo "    -p    Sets the port on which the odoo server will be reachable. Default: 8069."
	echo
	echo "    -r    Delete the database and odoo containers, as well as the bridge network between them."
	echo "          The containers and network will be re-created when you run the tests next time."
	echo "          The exit code is 0, also when nothing was deleted."
	echo 
	echo "    -v    Displays the version of the script."
	echo
	echo "Examples:"
	echo
	echo "Run the test suite of module 'my_module' in a loop and show full color output:"
	echo "$ $0 my_module"
	echo
	echo "Install/update my_module and run it from a set of docker container, on odoo 16 and in development mode:"
	echo "$ $0 -g 16 -d my_module"
	echo
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

	trace "truncating trace files. BYE BYE! :)"
	truncate $TRACE >/dev/null 2>&1
}

function ctrl_c() {
	echo "Stopping containers ..."
	trace "Stopping odoo server"
	docker stop $DOCKER_ODOO_FULL_NAME >>$TRACE 2>&1
	trace "Stopping postgres server"
	docker stop $DOCKER_PG_FULL_NAME >>$TRACE 2>&1
	echo "Done."
	exit 0
}

trace "*** Script starting..."

# Check if all dependencies are installed..
trace "Verifying that docker is installed."
command -v docker >>$TRACE 2>&1 || please_install docker docker.io

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

while getopts "dg:hp:rv" opt; do
	trace "Parsing option [$opt] now:"
	case $opt in
	d)
		trace "Swithing on DEVELOPMENT mode."
		DEV_MODE=1
		;;

	g)
		trace "-g detected."
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

	p)
		trace "-p detected."
		PORT=$OPTARG
		trace "HTTP port will be exposed on [$PORT]"
		;;

	r)
		trace "-r detected. deleting conatiner + networks."
		echo "Removing postgres and odoo containers used for running tests."
		echo "They will be created automatically again when you run $0."
		delete_containers
		echo "Done."
		exit 0
		;;

	v)
		echo "Script version: $SCRIPT_VERSION"
		exit 0
		;;

	*)
		trace "Error during parsing of command line parameters."
		exit 1
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

MODULE=$1
trace "Module to install/update and run: [$MODULE]."

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
DOCKER_HASH=$(echo "$PORT" "$DEV_MODE" "$MODULE" "$DOCKER_ODOO_IMAGE_NAME" "$DOCKER_PG_IMAGE_NAME" | md5sum | cut -d ' ' -f1)

DOCKER_NETWORK_FULL_NAME="$DOCKER_NETWORK-$DOCKER_HASH"
DOCKER_PG_FULL_NAME="$DOCKER_PG-$DOCKER_HASH"
DOCKER_ODOO_FULL_NAME="$DOCKER_ODOO-$DOCKER_HASH"

trace "DOCKER_HASH = [$DOCKER_HASH]"
trace "DOCKER_NETWORK_FULL_NAME = [$DOCKER_NETWORK_FULL_NAME]"
trace "DOCKER_PG_FULL_NAME = [$DOCKER_PG_FULL_NAME]"
trace "DOCKER_ODOO_FULL_NAME = [$DOCKER_ODOO_FULL_NAME]"

trace "DEV_MODE = [$DEV_MODE]"

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
	DEV_OPTS=""
	if [ $DEV_MODE -eq 1 ]; then
		DEV_OPTS="--dev xml,reload"
	fi
	docker create -v $(pwd):/mnt/extra-addons -p $PORT:8069 --name "$DOCKER_ODOO_FULL_NAME" --network "$DOCKER_NETWORK_FULL_NAME" -e HOST="$DOCKER_PG_FULL_NAME" "$DOCKER_ODOO_IMAGE_NAME" -d odoo -u "$MODULE" -i "$MODULE" --no-database-list $DEV_OPTS >>$TRACE 2>&1
else
	trace "Docker $DOCKER_ODOO_FULL_NAME still exists, re-using it."
fi

echo "Starting containers..."
# Make sure database is started.
trace "Starting the postgres server."
docker start $DOCKER_PG_FULL_NAME >>$TRACE 2>&1

timestamp=$(date --rfc-3339=seconds | sed "s/ /T/")
trace "Timestamp when we are running: $timestamp"

trace "(Re)starting the odoo server to run the module."
docker start $DOCKER_ODOO_FULL_NAME >>$TRACE 2>&1

trap ctrl_c INT
docker logs -f --since $timestamp $DOCKER_ODOO_FULL_NAME