#!/bin/bash
echo "Removing postgres and osoo containers used for running tests."
echo "They will be created automatically again when you run ./run-tests.sh." 
docker rm -f run-odoo-tests-odoo
docker rm -f run-odoo-tests-pg
docker network rm run-odoo-tests-network

