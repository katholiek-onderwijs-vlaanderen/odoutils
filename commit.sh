#!/bin/bash
eval $(ssh-agent)
ssh-add ~/.ssh/id_ed25519
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
