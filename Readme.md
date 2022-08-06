# OS : Ubuntu 20.04.1
# CNI : flannel
# CRI : Docker engine with cri-dockerd.sock not containerd.sock
# k8s version : latest

# This script is a kubernetes environment setup for personal user

## Prerequisites
#### 1. Disable swap
#### 2. Fix the ethernet IP
#### 3. Login as root

## Process List
#### 1. Disable ufw
#### 2. Install Docker
#### 3. Change docker's cgroup driver into systemd to match that of kubelet
#### 4. Let iptables see bridged traffic
#### 5. Install kubeadm & kubelet & kubectl
#### 6. Initialize the control plane node
#### 7. Install CNI network addon(weave net)
#### 8. Enable kubectl & kubeadm command auto completed
#### 9. Install ssh and allow ports for kubernetes master node

## After the whole process...
#### Just exit and go back to your home directory, then type 'source .bashrc'

## Good Luck
