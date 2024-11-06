#!/usr/bin/env bash

# e - script stops on error (return != 0)
# u - error if undefined variable
set -eu

# Version of the script
SCRIPT_VERSION=0.1

# Temp file where debug tracing is written. Tail it to debug the script.
TRACE=/tmp/odoutils-trace.log

# Temp folder for building the custom docker image
DOCKER_BUILD_DIR=/tmp/odoutils-docker-build

# Temp filie that is used to communicate from the subproces to the main proces that docker stop 
# is due to changes in files, signaling that - instead of exiting the script - we should restart the odoo server.
ODORUN_RESTART_DUE_TO_CHANGES_DETECTED=/tmp/odorun-restart-due-to-changes-detected

# Base names for dockers.
# The actual name incorporates a hash that is dependent on module to test, odoo version and database version.

# Base name of the docker container with odoo that runs the test suite.
DOCKER_ODOO=odorun-odoo
# Base name of the docker container that runs the postgres that is backing the odoo instance running the test suite.
DOCKER_PG=odorun-pg
# Base name of the user-defined bridge network that connects the odoo container with the database container.
DOCKER_NETWORK=odorun-network

# Base name (without version) to use for odoo docker images.
DOCKER_ODOO_IMAGE_BASE=odoo
#DOCKER_ODOO_IMAGE_BASE=odoo-with-icecream
# Name of the docker image that is used to run the test suite.
DOCKER_ODOO_IMAGE_NAME=$DOCKER_ODOO_IMAGE_BASE:15
# Name of the docker image that is used for the backing database of the odoo instance that runs the test suite.
DOCKER_PG_IMAGE_NAME=postgres:latest

# On what port on the host machine will the http port be mapped? Default: 8069.
# Can be overridden using the -p flag.
PORT=8069

# On what port should the postgres server be exposed?
# Can be set using the -b flag.
PG_PORT=

# List of environment variables to import into the container.
# default: None.
ENV_VARS=

function trace() {
	echo "$1" >>"$TRACE" 2>&1
}

function please_install {
	echo "This script requires these command to run:"
	echo
	echo " - docker (from docker.io)"
	echo
	echo "Please install them."
	echo
	echo "On Ubuntu for example:"
	echo
	echo "$ sudo apt-get install docker.io"
	echo
  echo "On Mac, you can use brew (or an alternative method):"
  echo
  echo "$ brew install --cask docker"
  echo 
	exit 1
}

function usage_message {
	echo "Usage: $0 [-b ] [-g] [-h] [-p] [-r] [-e] [-v] [-d] odoo_module_name1 [odoo_module_name2]"
}

function help_message {
	echo "$0 is utility to easily run odoo modules in a docker container."
	echo "It uses docker containers to isolate the entire process of running the tests from the rest of your system."
	echo "No need for manually restarting the server: the server will be restarted on file change."
	echo
	echo "Options:"
	echo
  echo "    -b    Sets the port on which the postgres server will be reachable. Default: not exposed."
  echo
	echo "    -g    Selects the odoo version to run. Tested with: 14,15 and 16. Default: 15."
	echo
	echo "    -h    Displays this help message."
	echo 
	echo "    -p    Sets the port on which the odoo server will be reachable. Default: 8069."
	echo
	echo "    -r    Delete the database and odoo containers, as well as the bridge network between them."
	echo "          The containers and network will be re-created when you run the tests next time."
	echo "          The exit code is 0, also when nothing was deleted."
	echo
  echo "    -e    Comma separated of environment variables to import into the container."
  echo "          Example: $0 -e MY_ENV_VAR1,VAR2 mymodule_to_run"
  echo "          This will set the environment variables MY_ENV_VAR1 and VAR2 in the odoo container to the current value."
  echo "          Do mind that the variable values will be fixed, and only updated after rebuilding the docker image."
  echo "          You can use $0 -r to remove the docker image. After this a full rebuild will be done when starting odorun."
	echo
  echo
	echo "    -v    Displays the version of the script."
  echo
  echo
	echo "    -d    Trace the script for debugging purposes."
	echo "          Run the script itself first in a separate terminal session, then $0 -d to trace it."
	echo
	echo "Examples:"
	echo
	echo "Run the module 'my_module' in a loop and show full color output:"
	echo "$ $0 my_module"
	echo
	echo "Install/update my_module and run it from a set of docker container, on odoo 16:"
	echo "$ $0 -g 16 my_module"
	echo
	echo "Run the module 'my_module' in a loop - restarting the service ANY time a file is updated."
	echo "$ $0 -a my_module"
	echo
	echo "run the module 'my_module' on port 9090:"
	echo "$ $0 -p 9090 my_module"
	echo
	echo "install both 'my_module_A' and module 'my_module_B' and run the odoo server:"
	echo "$ $0 my_module_A my_module_B"
	echo
}

function remove_everything {
	if [ $(docker ps -a | grep "$DOCKER_ODOO" | wc -l) -gt 0 ]; then
		trace "Deleting all odoo containers."
		docker rm -v -f $(docker ps -a | grep "$DOCKER_ODOO" | cut -f 1 -d ' ') >>$TRACE
	else
		trace "No odoo containers found to delete."
	fi
	if [ $(docker ps -a | grep "$DOCKER_PG" | wc -l) -gt 0 ]; then
		trace "Deleting all pg containers."
		docker rm -v -f $(docker ps -a | grep "$DOCKER_PG" | cut -f 1 -d ' ') >>$TRACE
	else
		trace "No pg containers found to delete."
	fi

	if [ $(docker network ls | grep "$DOCKER_NETWORK" | wc -l) -gt 0 ]; then
		trace "Deleting all networks."
		docker network rm $(docker network ls | grep "$DOCKER_NETWORK" | cut -f 1 -d ' ') >>$TRACE
	else
		trace "No bridge networks found to delete."
	fi

	if [ $(docker image ls | grep "^odorun-" | wc -l) -gt 0 ]; then
		trace "Deleting odorun images."
		docker image rm $(docker image ls | awk 'BEGIN {IFS="\t"} $0 ~ /^odorun-/ { print $1 ":" $2 }') >>$TRACE
	else
		trace "No odorun images found to delete."
	fi

	trace "truncating trace files. BYE BYE! :)"
	truncate --size 0 $TRACE >/dev/null 2>&1
}

# Start the odoo container, and attaches to it to allow interactive debugging (pdb).
function run_server_interactive {
	trace "RUN - Running server."

	timestamp=$(date --rfc-3339=seconds | sed "s/ /T/")
	trace "RUN - Timestamp when we are (re)starting: $timestamp"
	trace "RUN - (Re)starting the odoo server to run the module."
	docker restart $DOCKER_ODOO_FULL_NAME >>$TRACE 2>&1
	trace "RUN - (Re)start command done."

	trace "RUN - Attaching to docker."
	docker attach $DOCKER_ODOO_FULL_NAME
	trace "RUN - docker attach command exited."
	#docker logs -f --since $timestamp $DOCKER_ODOO_FULL_NAME &
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

  trace "Parsing [$#] command line arguments."
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

# Function to calculate the hash of the watched files and folders for restarting.
#
# echoes back a hash value.
function calculate_hash() {
		echo $(find "$@" -type f -exec ls -l --full-time {} + | sort | md5sum)
}

function stop_docker_on_file_change() {
  trace "STOP - Watching for changes in background."

  CURRENT_HASH=$(calculate_hash)
  while true; do
    trace "STOP - beginning loop."

    trace "STOP - checking parent process $$."
    # Check that parent process is still active
    if ! ps -p $$ > /dev/null; then
      trace "STOP - parent process is not active."
      trace "STOP - RETURN"
      return
    else
      trace "STOP - parent process is still active. Continuing."
    fi

    # Check if changes were detected.
    trace "STOP - checking for changes."
    if [ "$(calculate_hash)" != "$CURRENT_HASH" ]; then
      trace "STOP - changes detected."
      CURRENT_HASH=$(calculate_hash)
      # The script is in a loop, so stopping the docker here,
      # will cause the script to restart it.
      #
      # create the signal file that tells the main loop to continue,
      # rather than existing.
      trace "STOP - Creating signal file."
      touch "$ODORUN_RESTART_DUE_TO_CHANGES_DETECTED"

      trace "STOP - Stopping docker."
      echo -n "File changes detected. Restarting odoo server -> "
      docker stop $DOCKER_ODOO_FULL_NAME >>"$TRACE" 2>&1
      trace "STOP - docker stop command done."
      trace "STOP - RETURN"
      return
    else
      trace "STOP - no changes detected. Continuing."
    fi

    # Check that parent process is still active
    if [ "$(calculate_hash)" == "$CURRENT_HASH" ]; then
      sleep 1
    fi
  done
}

function stop_odoo() {
	trace "Stopping odoo server"
	docker stop "odorun-$DOCKER_HASH" >>$TRACE 2>&1
}

function stop_database() {
	trace "Stopping postgres server"
	docker stop $DOCKER_PG_FULL_NAME >>$TRACE 2>&1
}

function create_log_suppress_module() {
  # $1 is the location where you want to create the odoo module 
  #    that contains the code that does the log suppressions during debugging.
  
  trace "Creating log suppression module at $1/log_suppress"

  mkdir "$1/log_suppress"
  cat >"$1/log_suppress/__init__.py" <<EOT
import logging
import sys

def filter_logs_during_debug(record):
    debugging = False
    thread_ids = sys._current_frames().keys()
    for thread_id in thread_ids:
        frame = sys._current_frames()[thread_id]
        while frame:
            code = frame.f_code
            # if name is 'trace_dispatch' in filename ending in 'bdb.py' than we are in debugging mode.
            # Unfortunatile threading only adds gettrace() function as of python 3.10.
            if code.co_name == 'trace_dispatch' and code.co_filename.endswith('bdb.py'):
                debugging = True
                break
            frame = frame.f_back

    return not debugging

root_logger = logging.getLogger()
handlers = root_logger.handlers
for handler in handlers:
    handler.addFilter(filter_logs_during_debug)  
EOT

  # Write manifest
  cat >"$1/log_suppress/__manifest__.py" <<EOT
{
    'name': 'Log suppress for pdb',
    'version': '1.0.0',
    'author': 'Dimitry D hondt',
    'license': 'LGPL-3',
    'depends': [
    ],
    'summary': "Module that suppresses logging output during debugging sessions.",
    'description': "Module that suppresses logging output during debugging sessions.",
    'category': '',
    'demo': [],
    'data': [],
    'installable': True,
    'application': False,
    'auto_install': True,
    'assets': {    },
    'sequence': 100,
}
EOT

  trace "Done creating log suppression module."
}

# Create a docker image that contains all the pip dependencies found in requirements.txt
function create_docker_image() {
  # If no requirements.txt file found, create an empty one.
  if [ ! -f requirements.txt ]; then
    touch requirements.txt
  fi

  # If the docker image exists -> skip
  trace "Scanning if docker exists: odorun-$DOCKER_HASH"
  if [ $(docker image ls | grep "odorun-$DOCKER_HASH" | wc -l) -eq 1 ]; then
    trace "Docker image is already available. Skipping build step for docker."
    return
  fi
  trace "Docker image not found. Creating it."

  rm -rf "$DOCKER_BUILD_DIR"
  mkdir -p "$DOCKER_BUILD_DIR"

  create_log_suppress_module $DOCKER_BUILD_DIR

  touch "$DOCKER_BUILD_DIR/Dockerfile"
  echo "FROM $DOCKER_ODOO_IMAGE_NAME" >>"$DOCKER_BUILD_DIR/Dockerfile"
  echo "" >>"$DOCKER_BUILD_DIR/Dockerfile"

  cp requirements.txt "$DOCKER_BUILD_DIR"
  echo "USER root" >>"$DOCKER_BUILD_DIR/Dockerfile"
  echo "COPY requirements.txt ." >>"$DOCKER_BUILD_DIR/Dockerfile"
  echo "RUN mkdir /usr/lib/python3/dist-packages/odoo/addons/log_suppress" >>"$DOCKER_BUILD_DIR/Dockerfile"
  echo "COPY log_suppress/* /usr/lib/python3/dist-packages/odoo/addons/log_suppress/" >>"$DOCKER_BUILD_DIR/Dockerfile"
  echo "RUN pip3 install -r requirements.txt" >>"$DOCKER_BUILD_DIR/Dockerfile"
  echo "USER odoo" >>"$DOCKER_BUILD_DIR/Dockerfile"

  # Include the environment variables in the docker image.
  # ENV_VARS contains a comma-separated list of environment variables to import into the container.
  # For each item in the comma-separated list, we will add an ENV instruction to the Dockerfile.
  if [ "$ENV_VARS" != "" ]; then
    trace "Adding environment variables to the docker image."
    IFS=',' read -ra ENV_VARS_ARRAY <<<"$ENV_VARS"
    echo "ENV_VARS_ARRAY = [${ENV_VARS_ARRAY[@]}]"
    for x in "${ENV_VARS_ARRAY[@]}"; do
      if [[ -z ${!x+x} ]]; then
          echo "Variable $x is not present in the environment. Exiting."
          exit 1
      else
          echo "ENV $x=${!x}" >>"$DOCKER_BUILD_DIR/Dockerfile"
      fi
    done
  fi

  # No longer showing docker file, as it could reveal sensitive information, like
  # environment variables that are used to pass in system account passwords.
  echo "Building docker image."
  # No longer showing output of docker build, as it could reveal sensitive information, same as above.
  docker build "$DOCKER_BUILD_DIR" -t "odorun-${DOCKER_HASH}" >/dev/null 2>&1
}

touch "$TRACE"
truncate -s 0 "$TRACE"
trace "---------------------------"
trace "----- Script STARTING -----"
trace "---------------------------"

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

while getopts "b:dg:hp:rve:" opt; do
	trace "Parsing option [$opt] now:"
	case $opt in
  b)
    PG_PORT=$OPTARG
    ;;

	g)
		trace "-g detected."
		VERSION=$OPTARG
		DOCKER_ODOO_IMAGE_NAME=$DOCKER_ODOO_IMAGE_BASE:$VERSION
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
		echo "Removing docker images + postgres and odoo containers used for running modules."
		echo "They will be created automatically again when you run $0."
		remove_everything
		echo "Done."
		exit 0
		;;

  e) 
    trace "-e detected. Will copy the current value of the specified environment variables into the odoo container."
    ENV_VARS=$OPTARG
    trace "Environment variables to set in the odoo container: [$ENV_VARS]"
    ;;



	v)
		echo "Script version: $SCRIPT_VERSION"
		exit 0
		;;

	d)
		touch "$TRACE"
		tail -f "$TRACE"
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

if [ $# -eq 0 ]; then
  echo "No module to run was specified."
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
:
# Parse command line argument, validate and convert into comma-separated list of modules to install and test.
MODULES=$(parse_cmd_line_arguments $@)

echo "Installing modules [$MODULES]"

# Log all variables for debugging purposes.
trace "Current DOCKER_ODOO_IMAGE_NAME=$DOCKER_ODOO_IMAGE_NAME"
trace "Current DOCKER_PG_IMAGE_NAME=$DOCKER_PG_IMAGE_NAME"
trace "Current DOCKER_NETWORK=$DOCKER_NETWORK"

# Calculate full names for containers and network bridge
DOCKER_HASH=$(echo "$PG_PORT" "$PORT" "$MODULES" "$DOCKER_ODOO_IMAGE_NAME" "$DOCKER_PG_IMAGE_NAME" "$SCRIPT_VERSION" "$ENV_VARS" | md5sum | cut -d ' ' -f1)

DOCKER_NETWORK_FULL_NAME="$DOCKER_NETWORK-$DOCKER_HASH"
DOCKER_PG_FULL_NAME="$DOCKER_PG-$DOCKER_HASH"
DOCKER_ODOO_FULL_NAME="$DOCKER_ODOO-$DOCKER_HASH"

trace "DOCKER_HASH = [$DOCKER_HASH]"
trace "DOCKER_NETWORK_FULL_NAME = [$DOCKER_NETWORK_FULL_NAME]"
trace "DOCKER_PG_FULL_NAME = [$DOCKER_PG_FULL_NAME]"
trace "DOCKER_ODOO_FULL_NAME = [$DOCKER_ODOO_FULL_NAME]"

create_docker_image

echo "Checking if the user-defined bridge network exists." >>$TRACE
if [ $(docker network ls | grep "$DOCKER_NETWORK_FULL_NAME" | wc -l) -eq 0 ]; then
	trace "Creating the user-defined bridge network."
	docker network create "$DOCKER_NETWORK_FULL_NAME" >>$TRACE 2>&1
else
	trace "User defined bridge network $DOCKER_NETWORK_FULL_NAME still exists, re-using it."
fi

trace "Checking if the postgres docker [$DOCKER_PG_FULL_NAME] exists."
if [ $(docker ps -a | grep "$DOCKER_PG_FULL_NAME" | wc -l) -eq 0 ]; then
	trace "Creating a postgres server.docker "
  PG_PORT_OPTION=""
  [ "$PG_PORT" != "" ] && PG_PORT_OPTION="-p $PG_PORT:5432"
	docker create $PG_PORT_OPTION -e POSTGRES_USER=odoo -e POSTGRES_PASSWORD=odoo -e POSTGRES_DB=postgres --network "$DOCKER_NETWORK_FULL_NAME" --name "$DOCKER_PG_FULL_NAME" "$DOCKER_PG_IMAGE_NAME" >>$TRACE 2>&1
else
	trace "Docker $DOCKER_PG_FULL_NAME still exists, re-using it."
fi

trace "Checking if the odoo docker exists."
if [ $(docker ps -a | grep "$DOCKER_ODOO_FULL_NAME" | wc -l) -eq 0 ]; then
	trace "Creating the odoo server to run the tests."
	command="docker create -v $(pwd):/mnt/extra-addons -p $PORT:8069 --name $DOCKER_ODOO_FULL_NAME --network $DOCKER_NETWORK_FULL_NAME -e HOST=$DOCKER_PG_FULL_NAME --interactive --tty odorun-$DOCKER_HASH --limit-time-real 1800 --limit-time-cpu 1800 -d odoo -u $MODULES -i $MODULES -l en_US --without-demo all" 
	#command="docker create -v $(pwd):/mnt/extra-addons -p $PORT:8069 --name $DOCKER_ODOO_FULL_NAME --network $DOCKER_NETWORK_FULL_NAME -e HOST=$DOCKER_PG_FULL_NAME --interactive --tty $DOCKER_ODOO_IMAGE_NAME --limit-time-real 1800 --limit-time-cpu 1800 -d odoo -u $MODULES -i $MODULES -l en_US --without-demo all" 
  echo $command
  $command >>$TRACE 2>&1
else
	trace "Docker $DOCKER_ODOO_FULL_NAME still exists, re-using it."
fi

echo "Starting containers..."
# Make sure database is started.
trace "Starting the postgres server."
docker start $DOCKER_PG_FULL_NAME >>$TRACE 2>&1

timestamp=$(date --rfc-3339=seconds | sed "s/ /T/")
trace "Timestamp when we are running: $timestamp"

while true; do
  rm -f "$ODORUN_RESTART_DUE_TO_CHANGES_DETECTED" >>"$TRACE" 2>&1
  stop_docker_on_file_change&
  run_server_interactive

  if [ -f "$ODORUN_RESTART_DUE_TO_CHANGES_DETECTED" ]; then 
    # Remove signal file.
    trace "MAIN - Changes detected, restarting server..."
  else
    trace "MAIN - no signal file detected - assuming manual stop."
    echo "Manual stop."
    stop_database
    exit 0
  fi
done

