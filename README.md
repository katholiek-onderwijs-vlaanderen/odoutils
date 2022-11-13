# odoutils.sh

Set of command line utilities for odoo development.
Currently two commands are implemented.

`odounit.sh` allows you to run the test suite for a module (in docker containers). It is designed to allow you to focus fully on test development
and implementation, rather than on restarting/upgrading servers, scanning logs for FAIL messages etc.
If provides a clear RED or GREEN display to allow you to very quickly know the status of your code.

`odorun.sh` is a script that runs odoo (using docker), and re-loads the server at the right times. It is designed to allow you to focus fully on doing 
development, rather than on restarting the server, upgrading modules, etc.. *Under development*

## odounit.sh

`Usage: ./odounit.sh [-h | -t | -r] [-p] [-o] [odoo_module_name]`

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

## 

# Contributing

A *high-level overview* of the technical design for `odounit.sh` is [described here](/docs/TECH_OVERVIEW_ODOUNIT.md).
For `odorun.sh` the high-level technical documentation is [located here](/docs/TECH_OVERVIEW_ODORUN.md).
Bug reporting can be done through the issues section.
Features can be suggested in the discussions section.
Please also use the discussions section for all other communication.

