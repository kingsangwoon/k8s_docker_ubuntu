#!/bin/bash

#------------- disable swap partition
sudo swapoff -a
echo "You must disable swap partition before installing k8s."
read -p "Did you turn off swap? [yes/no] " answer
if [ ${answer} = yes ] || [ ${answer} = y ] ; then
        echo ""
        else echo "disable swap first" && exit
fi

# static IP check
read -p "Is the system's IP fixed for your stable k8s environment? (yes/no) " answer
if [ ${answer} = yes ] || [ ${answer} = y ] ; then
        echo ""
        else echo "set IP static" && exit
fi

#------------- disable ufw
sudo systemctl stop ufw
sudo systemctl disable ufw

#------------- install docker
sudo apt-get remove docker docker-engine docker.io
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt update
sudo apt install -y docker-ce
