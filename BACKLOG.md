TO DO:

MUST

- [ ] Test fresh install on real ubuntu.
- [ ] Add technical docs.

SHOULD
- [ ] Add parameter to allow specifying the version of postgres to use. (will require refactoring options handling)
- [ ] Add parameter to allow specifying the version of odoo to use. (will require refactoring options handling)
- [ ] Create odorun.sh for running one or more modules from docker.
- [ ] Add message with command line syntax on how to install dependencies. (sudo apt-get install figlet ... docker.io)

COULD

WILL NOT
- [ ] Determine default postgres version automatically per version of odoo.

DONE:


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
