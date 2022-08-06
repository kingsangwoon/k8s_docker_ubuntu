#!/bin/bash

# check the must-be-done priorities
echo "1. disable swap"
echo "2. static IP"
echo "3. login as root"
echo "4. change the hostname. There should be no matching hostnames between each nodes"
read -e -p "Did you perform above all things? (yes/no) " answer
if [ ${answer} = yes ] || [ ${answer} = y ] ; then
        echo ""
        else echo "Make them done first!" && exit
fi

read -e -p "Do you wanna install nvidia container runtime? (yes/no) " answer
read -e -p "Enter the system's IP : " ip
read -e -p "Enter the user name you want to give administrator privilege : " user_name

#------------- disable ufw
systemctl stop ufw
systemctl disable ufw

#------------- install docker
apt update
apt install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

#-------------- make docker use systemd not cgroupfs
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker

#-------------- install nvidia docker(nvidia container toolkit)
if [ ${answer} = yes ] || [ ${answer} = y ] ; then

	distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
	curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
	curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
 	apt update && apt install -y nvidia-container-toolkit
	systemctl restart docker

	cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "default-runtime": "nvidia",
   "runtimes": {
      "nvidia": {
	    "path": "/usr/bin/nvidia-container-runtime",
	    "runtimeArgs": []
      }
   }
}
EOF
	   
	systemctl daemon-reload
	systemctl restart docker

fi

#-------------- install cri-dockerd
apt install -y golang-go
git clone https://github.com/Mirantis/cri-dockerd.git
cd cri-dockerd
mkdir bin
cd src && go get && go build -o ../bin/cri-dockerd

mkdir -p /usr/local/bin
cd ..
install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd
cp -a packaging/systemd/* /etc/systemd/system
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket

#------------- temporarily stop and disable containerd.sock
systemctl stop containerd.service
systemctl disable containerd.service

#------------- letting iptables see bridged traffic
echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.d/k8s.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/k8s.conf
sysctl --system

#------------- install kubeadm/kubelete/kubectl
apt-get update
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

#------------- enable kubectl & kubeadm auto-completion
echo "source <(kubectl completion bash)" >> /home/$user_name/.bashrc
echo "source <(kubeadm completion bash)" >> /home/$user_name/.bashrc

echo "source <(kubectl completion bash)" >> $HOME/.bashrc
echo "source <(kubeadm completion bash)" >> $HOME/.bashrc
source $HOME/.bashrc
