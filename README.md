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
| `-i`   | Module(s) to install. Comma separated list. If no module is given, the [module_to_test] on the command line will be installed. |
| `-i`   | Install one or more additional modules from the current folder. Comma separated list. The additional modules will be installed before the tests are run. |
| `-o`   | Run test suite once. Do not enter loop to re-run test suite on file change. |
| `-p`   | Do not output in color. Do not clear screen. |
| `-r`   | Deletes the database and odoo containers, as well as the bridge networks between them.<br/> The containers and networks will be re-created when you run the tests next time.<br/> The exit code is 0, also when nothing was deleted. |
| `-t`   | Allow you to override the --test-tags with a custom value. Useful for test isolation. See command line documentation of odoo for syntax. |
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
`$ [ $? -ne 0 ] && echo "At least one test failed, or module did not install."`

Open a second terminal session, while ./odounit.sh is running, and inspect the tail of the odoo log:

`$ ./odounit.sh -t`

Delete all containers and log files (by default containers are created and then reused for speed):

`$ ./odounit.sh -r`

Run a single test (test isolation):

`$ ./odounit.sh -t :class_name.test_name`

## odorun.sh

`Usage: ./odorun.sh [-h | -r] [-b] [-p] [-o] [-g] [odoo_module_name]`

`./odorun.sh` is a module runner for development. It allows you to fire up a fresh odoo container with a single command. It is designed to take care of module reloading, upgrading, etc.. Simply fire it up, develop your module, and then check result by hitting the refresh button on your browser. Restarts the odoo server and re-installs the module whenever a file was changed in your module's folder.

The script uses docker containers to isolate the entire process of running the odoo database and web server from the rest of your system.

![odoorun console output](/docs/odorun-console.png)

### Options:

| Option | Description |
| ------ | ----------- |
| `-b`   | Sets the port on which the postgres server will be reachable. Default: not exposed. |
| `-g`   | Select the odoo version you want run the module on. Tested with odoo 14, 15 and 16.<br/> Depending on the odoo version, a fitting postgres image will be used for the database container. The pg version used is the one advised in the odoo [developer's documentation](https://www.odoo.com/documentation/master/administration/install/install.html#postgresql). Default: 15 |
| `-h`   | Displays a help message. |
| `-i`   | Install one or more additional modules from the current folder. Comma separated list. |
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

### Debugging

You can use the [standard python pdb module](https://docs.python.org/3/library/pdb.html) for debugging.

In order to halt the execution of your code place the `breakpoint()` statement at the desired location:

![pdb_insert_breakpoint](/docs/breakpoint.png)

When `odounit.sh` or `odorun.sh` is running, it will halt execution at the breakpoint.
Next you can use pdb commands like `ll` (longlist),`p` (print),`n` (next), etc.. to debug your code:

![pdb_stopped](/docs/pdb-stopped.png)

Continue running the code using the `c` (continue) command:

![pdb_continue](/docs/pdb-continue.png)

A good introduction to using pdb can be [found here](https://realpython.com/python-debugging-pdb/).
A convenient cheat sheet is [located here](https://kapeli.com/cheat_sheets/Python_Debugger.docset/Contents/Resources/Documents/index).

Remove the `breakpoint()` statement from your code if you are done debugging :-)

Being able to enter the debugger in a specific point of your code is also convenient
if you want to try out some statements interactively. This can be a great help during development.

Debugging of code in a __running odoo server__ can be done, but you probably want to disable logging temporarily.
This can be done by adding the snippet of code below into your top-level __init__.py file:

```
# Add a hook in the breakpoint handler to temporarily disable odoo logging,
# so that the output of other workers than the one being debugged 
# do not get in your way during debugging.
#
# Re-enable the logging when the debugging session is done.
import sys
import logging

old_breakpointhook = sys.breakpointhook

def new_breakpointhook:
  old_root_logger_level = logging.getLogger().getEffectiveLevel()
  logging.getLogger().setLevel(logging.CRITICAL)
  try:
    old_breakpointhook()
  finally:
    logging.getLogger().setLevel(old_root_logger_level)

sys.breakpointhook = new_breakpointhook
```

For debugging purposes - `odorun.sh` the cli options `--limit-time-real` and `--limit-time-cpu` have been set high (10 minutes).

By and large it is advised to create a test case for the problem you encounter, and debug that.
Interactive debugging on the odoo server can, in some cases, be useful to gain better understanding of a bug.
But creating a test case to cover the bug is __essential__ TDD practice :-).

Example:

Setting a breakpoint in an odoo model:

![odoo_breakpoint](/docs/odoo-breakpoint.png)

Saving an object with end_date < start_date:

![odoo-stopped](/docs/odoo-stopped.png)

Note that the logging output of odoo is temporarily disabled, to not interfere with your debugging session.
After issuing `c` to continue execution, the server output logging is resumed:

![odoo-continued](/docs/odoo-continued.png)

# Contributing & Technical Documentation

A *high-level overview* of the technical design for `odounit.sh` is [described here](/docs/TECH_OVERVIEW_ODOUNIT.md).
For `odorun.sh` the high-level technical documentation is [located here](/docs/TECH_OVERVIEW_ODORUN.md).
Bug reporting can be done through the issues section.
Features can be suggested in the discussions section.
Please also use the discussions section for all other communication.

The current backlog is [located here](/BACKLOG.md).
