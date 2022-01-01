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
sudo apt-cache policy docker-ce
sudo apt install -y docker-ce

#------------- letting iptables see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

#------------- install kubeadm/kubelete/kubectl
sudo apt-get update
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

#------------- create a cluster
read -p "Enter the system's IP : " ip
sudo kubeadm init --control-plane-endpoint "${ip}:6443" --upload-certs --pod-network-cidr "10.244.0.0/16"

#------------- allow current account to use kubectl without "sudo"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#------------- install CNI network addon
sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

#------------- enable kubectl & kubeadm auto-completion
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "source <(kubeadm completion bash)" >> ~/.bashrc
source ~/.bashrc

#------------- enable ssh connection && open port 80
sudo apt install openssh-server
sudo ufw allow 22
sudo ufw allow 80

#------------- allow specific ports for k8s
sudo ufw allow 6443
sudo ufw allow 2379
sudo ufw allow 2380
sudo ufw allow 10250
sudo ufw allow 10251
sudo ufw allow 10252
sudo systemctl enable ufw
sudo systemctl start ufw
sudo ufw enable
