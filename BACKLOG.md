TO DO:

MUST
* Test fresh install on real ubuntu.
* Update README

SHOULD
* Add parameter to allow specifying the version of postgres to use. (must delete + create dockers if necessary)
* Add parameter to allow specifying the version of odoo to use. (must delete + create dockers if necessary)

* add --plain option that does not color/clear/fancy output. This should make testing the script easier.
* add --once parameter to do a single run (no loop)
* Make the script testable. (fake docker logs/create/etc..  + -trace option should allow for rappid prototyping.)
* exit codes 0 (all tests ok),1 (test failure) and 2 (ambiguous)

COULD
* Determine default postgres version automatically.
* extract logging into a function

WOULD

DONE:

* ~~combine remove script into the main script as --delete.~~
* ~~Rename the dockers to run-odoo-test-* instead of om-hospital-*~~
* ~~remove the use of --link for connection the database to the odoo docker (deprecated). Should use user-defined bridge network. (https://docs.docker.com/network/bridge/)~~
* ~~add --tail option to tail /tmp/run-tests-logs.txt~~
* ~~Add detection of ERROR messages, other than FAIL -> 3rd state for the screen (neutral) (add import in __init__.py that does not exist -> ERROR - but right now "SUCCESS")~~
* ~~Do not expose HTTP port for odoo.~~
* ~~Log output starting at the position of the first FAILED test.~~
* ~~Add parameter/configuration mechanism to allow specifying what module(s) to test.~~
* ~~Clean up list of failed tests.~~

REJECTED

* ~~Make postgres port dynamic. (https://docs.docker.com/network/)~~
