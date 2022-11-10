#!/bin/bash
git status
read -p "Commit all these changes? (y/n) " yn

case $yn in
[yY])
	read -p "Commit message: " msg
	git add .
	git commit -a -m "$msg"
	echo "Pushing..."
	git push
	exit
	;;
*) exit ;;
esac
