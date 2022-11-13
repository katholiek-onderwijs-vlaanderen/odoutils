# Technical overview

This document gives a high-level overview of the design of the script. If you want to contribute, this page should give you a head start.
Feedback on the technical documentation is welcome via the discussions section. 

## Network+Containers

The script uses docker containers to run the test suite of the module you specify.

More specifically 3 items are created (in this order of dependency):

* A user-defined bridge network that is used by the odoo container to connect to the pg container.
* A postgres container.
* An odoo container.

The necessary command line arguments for odoo-bin are passed in at creation time of the containers. More specifically: `-i` and `-u` to install and upgrade the module, as well as `--stop-after-init` and `--test-tags "/$MODULE"`. This makes odoo-bin install/upgrade the module, run all tests *only* for that module, and then exit. The odoo container is stopped at that time (but not removed, it is re-used next time the tests are run).

For more information on the command line options of odoo-bin see the [official odoo documentation](https://www.odoo.com/documentation/master/developer/cli.html).

## Scope for a network+containers set.

Since the command to run odoo has to *include* (at creation time) the name of the module to run tests for (among other things) and docker containers are *immutable*, we create a new pg+odoo+network combination for any combination of:

* module name
* odoo version
* postgres version

An md5hash is generated for each combination of those 3 input parameters, and is appended to the name of the docker containers and to the bridge network used:

`DOCKER_HASH=$(echo "$MODULE" "$DOCKER_ODOO_IMAGE_NAME" "$DOCKER_PG_IMAGE_NAME" | md5sum | cut -d ' ' -f1)`<br/>
`DOCKER_ODOO_FULL_NAME="$DOCKER_ODOO-$DOCKER_HASH"`

## Detecting file changes

To detect a change in the files of the module the user is testing, a combination of checking the filesystem and `inotifywait` is used.

More precisely:

1) When a test run starts we calculate a has for the entire module using `$(find "$MODULE" -type f -exec ls -l {} + | sort | md5sum)`
2) We then run the tests and parse the output of the odoo docker.
3) After the tests were run we calculate a new hash for the folder of the module the user is testing.
4) If there is a difference in both hash values, we run the tests again.<br/> Otherwise we wait for *any* event on any of the files in the module using `inotifywait -r -q "$MODULE"`

## Variables

The [source of the module](/odounit.sh) starts by documenting all variables used.

## Tracing & Debugging

The code of the module logs a verbose trace in `/tmp/odounit-trace.log`. Tail it for debugging. Uncommenting `set +x` at the start of the module source can also help during debugging.