TO DO:

MUST

- [ ] Test fresh install on real ubuntu for odorun.sh AND odounit.sh .
- [ ] Add unit tests for odorun.sh. 
- [ ] Cover all cases for reloading in oroun in unit tests.

SHOULD
- [ ] Add documentation for odorun.sh

COULD
- [ ] Add -q (quiet) flag to suppress output for odorun and odounit.
- [ ] Add -a (always) flag to odorun.sh for those that don't trust --web xml,reload. 

WILL NOT

DONE:


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
