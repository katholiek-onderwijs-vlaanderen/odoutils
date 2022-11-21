# Technical overview

This document gives a high-level overview of the design of `odorun.sh`. If you want to contribute, this page should give you a head start.
Feedback on the technical documentation is welcome via the discussions section. 

## Network+Containers

The script uses docker containers to run the test suite of the module you specify, in the same way as `odounit.sh`.

More specifically 3 items are created (in this order of dependency):

* A user-defined bridge network that is used by the odoo container to connect to the pg container.
* A postgres container.
* An odoo container.

The necessary command line arguments for odoo-bin are passed in at creation time of the containers. More specifically: `-i` and `-u` to install and upgrade the module.

The odoo container is stopped when the user presses CTRL-C (but not removed, it is re-used next time the tests are run).

For more information on the command line options of odoo-bin see the [official odoo documentation](https://www.odoo.com/documentation/master/developer/cli.html).

The *current folder* where you run `odorun.sh` is mapped as `/mnt/extra-addons` in the odoo container.

## Scope for a network+containers set.

Since the command to run odoo has to *include* (at creation time) the name of the module and docker containers are *immutable*, we create a new network and pg+odoo containers for any combination of values for these parameters:

* port number
* module name
* odoo version
* postgres version

An md5hash is generated for each combination of those input parameters, and is appended to the name of the docker containers and to the name of bridge network used.

## Detecting file changes

Detecting file changes is done in the same way as for `odounit.sh`, as [described here](/docs/TECH_OVERVIEW_ODOUNIT.md).

When a file change was detected. The odoo server is restarted and the module is re-installed.

This way the odoo server is always in a reliable state. Reliable enough for the user to not have to worry about server restarts any more :).

## Variables

The [source of the module](/odounit.sh) starts by documenting all variables used.

## Tracing & Debugging

The code of the module logs a verbose trace in `/tmp/odoutils-trace.log`. Tail it for debugging.

## Unit tests

A suite of test scripts is located in `tests` and can be run using `test-odorun.sh`. The test suite uses [shunit2](https://github.com/kward/shunit2) as xUnit testing framework.