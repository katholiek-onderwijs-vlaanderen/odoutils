TO DO:

MUST

- [ ] Add support for requirements.txt -> should build a custom docker image with installed dependencies. Hash must include content of requirements.txt.
- [ ] Add unit tests for odorun.sh. Cover all cases for reloading in odorun in unit tests. Does changing model .py work? 
- [ ] Add smtp4dev to odorun.sh to catch all mails, yet have a functional mail server - and allow for inspecting mails in dev mode.

SHOULD

- [ ] Encapsulate code to suspend odoo logging during debug in module that is installed.
- [ ] update code snippet for log suppression to only install filter on appenders that write to STDOUT/STDERR, not to other (file/...) appenders.
- [ ] Investigate on how to make logging of odoo model objects convenient for logging/debugging.
- [ ] Investigate icecream package for logging execution / data of code.
- [ ] remove dependencies check if running in plain mode -> should not complain about figlet / tput / .. not being installed.
- [ ] Add -s flag to run slow tests to odounit.sh. By default don't run slow tests.
- [ ] Add -m for setting the http port for the smtp4dev mail server.

COULD
- [ ] Check that reloading the browser on windows/linux can also be automated in odorun :-)

WILL NOT
- [ ] add -a option to auto-install dependencies in automation context?
- [ ] Add -q (quiet) flag to suppress output for odorun and odounit.

DONE:

- [x] Stop pg container on CTRL-C (otherwise it keeps running - not stop after test run - for speed)
- [x] Investigate if Pdb allows PRE / POST handlers to be registered -> disable / enable logging in there?
- [x] Add support for pdb to odorun (like in odounit)
- [x] Added support to use pdb interactively to odounit.
- [x] Added -t option to allow test isolation.
- [x] Added loop-tests.sh script.
- [x] Fix error message when a module is not found in CWD. Add unit test in test suite. (parse_cmd_line function)
- [x] Test fresh install on real ubuntu for odorun.sh AND odounit.sh .
- [x] add -i support for installing additional modules as dependencies
- [x] Add -b for setting a data_b_ase port - so you can point pgadmin at it :)
- [x] add -d (debug) flag to trace scripts for debugging.
- [x] Add documentation for odorun.sh
- [x] Add -a (always) flag to odorun.sh for those that don't trust --web xml,reload. 
- [x] Make reloading more robust for odorun. Handle changes to existing xml/.py files using --web and everything else with full reload/recreate.
- [x] Handle / at end of module. Cover in unit test.
- [x] Add technical documentation for odorun.sh
- [x] Remove -d flag from odorun.sh. The scope of the tool is a runner script for developers, not something else.
- [x] Create odorun.sh for running one or more modules inside a docker container.
- [x] Determine default postgres version automatically per version of odoo.
- [x] Add parameter to allow specifying the version of odoo to use. (will require refactoring options handling)
- [x] Add -v for script versioning.
- [x] Add message with command line syntax on how to install dependencies. (sudo apt-get install figlet ... docker.io)
- [x] Add technical docs.
- [x] Update README.md to add user documentation.
- [x] Added set -euo pipefail to make script more robust.
- [x] Rename repository to odoutils.sh.
- [x] Rename test script to odounit.sh.
- [x] --remove should use prefix on container / network same to select, making --remove more robust.
- [x] Add prefix to all container names + network name.
- [x] extract logging into a function.
- [x] Cover functionality with test suite.
- [x] Speed up unit testing.
- [x] Make the script testable.
- [x] add --plain option that does not color/clear/fancy output. This should make testing the script easier.
- [x] add --once parameter to do a single run (no loop).
- [x] exit codes 0 (all tests ok),1 (test failure) and 2 (ambiguous).
- [x] combine remove script into the main script as --delete.
- [x] Rename the dockers to run-odoo-test-* instead of om-hospital-*
- [x] remove the use of --link for connection the database to the odoo docker (deprecated). Should use user-defined bridge network.
- [x] add --tail option to tail /tmp/run-tests-logs.txt
- [x] Add detection of ERROR messages, other than FAIL -> 3rd state for the screen (neutral) (add import in __init__.py that does not exist -> ERROR - but right now "SUCCESS").
- [x] Do not expose HTTP port for odoo.
- [x] Log output starting at the position of the first FAILED test.
- [x] Add parameter/configuration mechanism to allow specifying what module(s) to test.
- [x] Clean up list of failed tests.

REJECTED

- [ ] Make postgres port dynamic. 
- [ ] Add parameter to allow specifying the version of postgres to use. (will require refactoring options handling)
- [ ] Add pgadmin to odorun.sh.
- [ ] Find a way to control the order of installation of modules, if we are to put test data in a separate module..
