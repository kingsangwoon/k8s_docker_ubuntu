#!/bin/bash

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
