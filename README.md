# odoutils.sh

Set of command line utilities for odoo development.
Currently two commands are implemented.

`odounit.sh` allows you to run the test suite for a module (in a docker container). It is designed to allow you to focus fully on test development
and implementation, rather than on restarting/upgrading servers, scanning logs for FAIL messages etc.
If provides a clear RED or GREEN display to allow you to very quickly know the status of your code.

`odorun.sh` is a script that runs an odoo module (using docker) for development purposes, and restarts that server at the right times. It is designed to allow you to focus fully on doing development, rather than on restarting, upgrading modules, etc..

These tools are opinionated in the sense that they assume that you strive for immutable servers that can be (re)created in a deterministic fashion. In other words: it assumes that all details of installing your module are automated. 

If you require manual interventions on your server, you will not like these tool :-)

1. [odounit.sh](#odounitsh)
2. [odorun.sh](#odorunsh)

## Installation

Download [`odounit.sh`](/odounit.sh) and [`odorun.sh`](/odorun.sh).
Place them in your location of choice, and make them executable:

```
$ cd ~
$ mkdir odoutils
$ cd odoutils
$ wget https://raw.githubusercontent.com/katholiek-onderwijs-vlaanderen/odoutils/main/odounit.sh -O odounit.sh
$ wget https://raw.githubusercontent.com/katholiek-onderwijs-vlaanderen/odoutils/main/odorun.sh -O odorun.sh
$ chmod u+x odounit.sh
$ chmod u+x odorun.sh
``` 

To make running the scripts convenient, you can consider adding 2 aliasses to your `~/.bash_aliases` script, like this:

```
$ vi ~/.bash_aliases

alias odorun='~/odoutils/odorun.sh'
alias odounit='~/odoutils/odounit.sh'
```


## odounit.sh

`Usage: ./odounit.sh [-h | -t | -r] [-p] [-o] [-g] [odoo_module_name]`

`./odounit.sh` is a test suite runner for odoo modules. It is designed to allow you get quick feedback on changes
you make in the test suite or the implementation of your module.
It can be used interactively (default), in which case it will continuously monitor your sources and
(re)run the test suite when a change is detected. A clear visual message is given when tests pass or fail.

![Success](/docs/odounit-sh-success.png)
![Failed](/docs/odounit-sh-failed.png)

Alternatively you can use it to run a test suite once, and check the exit code for scripting purposes in a CI/CD setup.

It uses docker containers to isolate the entire process of running the tests from the rest of your system.

### Options:

| Option | Description |
| ------ | ----------- |
| `-g`   | Select the odoo version you want the test suite to run on. Tested with odoo 14, 15 and 16.<br/> Depending on the odoo version, a fitting postgres image will be used for the database container. The pg version used is the one advised in the odoo [developer's documentation](https://www.odoo.com/documentation/master/administration/install/install.html#postgresql). |
| `-h`   | Displays help message. |
| `-o`   | Run test suite once. Do not enter loop to re-run test suite on file change. |
| `-p`   | Do not output in color. Do not clear screen. |
| `-r`   | Deletes the database and odoo containers, as well as the bridge networks between them.<br/> The containers and networks will be re-created when you run the tests next time.<br/> The exit code is 0, also when nothing was deleted. |
| `-t`   | Tails the output of the test run.<br/> You should start `./odounit.sh module_name` first, and issue `./odounit.sh -t` to view logs in a separate terminal session. |
| `-v`   | Displays the script version number. |


### Exit codes:

Mostly useful in combination with -o -p, for scripting purposes.

| Code | Description |
| ---- | ----------- |
| 0    | All tests passed. |
| 1    | At least one test failed. |
| 2    | An (unkown) error occured during running of the tests. (Module install failed / ...) |

### Examples:

Run the test suite of module 'my_module' in a loop and show full color output:

`$ ./odounit.sh my_module`

Run the test suite for module 'my_module' once and output in plain text, then check if failures were detected:

`$ ./odounit.sh -p -o my_module`<br>
`$ [ $? -eq 1 ] && echo "At least one test failed."`

Open a second terminal session, while ./odounit.sh is running, and inspect the tail of the odoo log:

`$ ./odounit.sh -t`

Delete all containers and log files (by default containers are created and then reused for speed):

`$ ./odounit.sh -r`

## odorun.sh

`Usage: ./odorun.sh [-h | -r] [-o] [-g] [odoo_module_name]`

`./odorun.sh` is a module runner for development. It allows you to fire up a fresh odoo container with a single command. It is designed to take care of module reloading, upgrading, etc.. Simply fire it up, develop your module, and then check result by hitting the refresh button on your browser. 

The script uses docker containers to isolate the entire process of running the odoo database and web server from the rest of your system.

![odoorun console output](/docs/odorun-console.png)

### Options:

| Option | Description |
| ------ | ----------- |
| `-g`   | Select the odoo version you want run the module on. Tested with odoo 14, 15 and 16.<br/> Depending on the odoo version, a fitting postgres image will be used for the database container. The pg version used is the one advised in the odoo [developer's documentation](https://www.odoo.com/documentation/master/administration/install/install.html#postgresql). Default: 15 |
| `-h`   | Displays a help message. |
| `-p`   | Set the HTTP port to run the odoo server on. Default: 8069. |
| `-r`   | Deletes the database and odoo containers, as well as the bridge networks between them.<br/> The containers and networks will be re-created when you run the module next time.<br/> The exit code is 0, also when nothing was deleted. |
| `-v`   | Displays the script version number. |

At the moment the postgres port is exposed on port 5433. Will make this an option in the future.

### Examples:

Run `my_module` on odoo 16:

`$ ./odorun.sh -g 16 my_module`

Delete all containers and log files (by default containers are created and then reused for speed):

`$ ./odorun.sh -r`

Run `my_module` on port 9090:

`$ ./odorun.sh -p 9090 my_module`

Run `my_module` and always restart on any file change (not relying on --web xml,reload):

`$ ./odorun.sh -a my_module`

# Contributing

A *high-level overview* of the technical design for `odounit.sh` is [described here](/docs/TECH_OVERVIEW_ODOUNIT.md).
For `odorun.sh` the high-level technical documentation is [located here](/docs/TECH_OVERVIEW_ODORUN.md).
Bug reporting can be done through the issues section.
Features can be suggested in the discussions section.
Please also use the discussions section for all other communication.

The current backlog is [located here](/BACKLOG.md).