# Technical overview

This document gives a high-level overview of the design of `odorun.sh`. If you want to contribute, this page should give you a head start.
Feedback on the technical documentation is welcome via the discussions section. 

## Network+Containers

The script uses docker containers to run the test suite of the module you specify, in the same way as `odounit.sh`.

More specifically 3 items are created (in this order of dependency):

* A user-defined bridge network that is used by the odoo container to connect to the pg container.
* A postgres container.
* An odoo container.

The necessary command line arguments for odoo-bin are passed in at creation time of the containers. More specifically: `-i` and `-u` to install and upgrade the module, as well as `--dev xml,reload` to trigger reading of xml files from disk rather than database, and to trigger reloading of changes to python files.

The odoo container is stopped when the user presses CTRL-C (but not removed, it is re-used next time the tests are run).

For more information on the command line options of odoo-bin see the [official odoo documentation](https://www.odoo.com/documentation/master/developer/cli.html).

The *current folder* where you run `odounit.sh` is mapped as `/mnt/extra-addons` in the odoo container.

## Scope for a network+containers set.

Since the command to run odoo has to *include* (at creation time) the name of the module to run tests for (among other things) and docker containers are *immutable*, we create a new network and pg+odoo conatiners for any combination of values for these 3 parameters:

* port number
* module name
* odoo version
* postgres version

An md5hash is generated for each combination of those input parameters, and is appended to the name of the docker containers and to the name of bridge network used.

## Detecting file changes

When only changes to xml or python files that already existed when the odoo server was started, then nothing is done. We rely on --dev xml,reload to handle those cases properly.

If, on the other hand:

* a change to any other file was detected,
* a new file is detected, 
* or if a file was deleted, 

then the full docker container and database container is destroyed, and recreated from scratch. This will reinstall the module under development.

This way the odoo server is always going to be in a reliable state. Reliable enough for the user to not have to worry about server restarts any more :).

## Variables

The [source of the module](/odounit.sh) starts by documenting all variables used.

## Tracing & Debugging

The code of the module logs a verbose trace in `/tmp/odorun-trace.log`. Tail it for debugging.

## Unit tests

A suite of test scripts is located in `tests` and can be run using `test-odorun.sh`. The test suite uses [shunit2](https://github.com/kward/shunit2./com) as xUnit testing framework.