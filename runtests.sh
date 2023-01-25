#!/bin/bash
cd tests
echo "Running test-odounit.sh"
./test-odounit.sh
echo "Running test-odorun.sh"
./test-odorun.sh
cd ../tests2
echo "Running test-odounit2.sh"
./test-odounit2.sh
