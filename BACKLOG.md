TO DO:

* Test fresh install on ubuntu.
* Add parameter+configuration mechanism to allow specifying the version of postgres to use. (must delete + create dockers if necessary)
* Add parameter+configuration mechanism to allow specifying the version of odoo to use. (must delete + create dockers if necessary)
* Make postgres port dynamic. (https://docs.docker.com/network/)
* Determine default postgres version automatically.
* extract logging into a function
* add -trace option that does not color/clear/fancy output. This should make testing the script easier.
* add -log option to tail /tmp/run-tests-logs.txt
* Make the script testable. (fake docker logs/create/etc..  + -trace option should allow for rappid prototyping.)
* Add detection of ERROR messages, other than FAIL -> 3rd state for the screen (neutral) (add import in __init__.py that does not exist -> ERROR - but right now "SUCCESS")

DONE:

* ~~Do not expose HTTP port for odoo.~~
* ~~Log output starting at the position of the first FAILED test.~~
* ~~Add parameter/configuration mechanism to allow specifying what module(s) to test.~~
* ~~Clean up list of failed tests.~~
