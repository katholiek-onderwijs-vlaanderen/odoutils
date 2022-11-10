#!/bin/bash
echo "Removing postgres and osoo containers used for running tests."
echo "They will be created automatically again when you run ./run-tests.sh." 
docker rm -f om-hospital-test-pg
docker rm -f om-hospital-test-odoo
docker network rm run-odoo-tests-network

