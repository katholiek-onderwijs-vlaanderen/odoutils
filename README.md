# odoutils.sh

Set of command line utilities for odoo development.
Currently a single command is implemented that allows you to run the test suite for a module: `odounit.sh`

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
| `-h`   | Displays help message. |
| `-o`   | Run test suite once. Do not enter loop to re-run test suite on file change. |
| `-p`   | Do not output in color. Do not clear screen. |
| `-r`   | Deletes the database and odoo containers, as well as the bridge networks between them.<br/> The containers and networks will be re-created when you run the tests next time.<br/> The exit code is 0, also when nothing was deleted. |
| `-t`   | Tails the output of the test run.<br/> You should start `./odounit.sh module_name` first, and issue `./odounit.sh -t` to view logs in a separate terminal session. |

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

# Contributing

A *high-level overview* of the technical design is [described here](/docs/TECH_OVERVIEW.md).
Bug reporting can be done through the issues section.
Features can be suggested in the discussions section.
Please also use the discussions section for all other communication.