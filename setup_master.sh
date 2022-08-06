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
systemctl stop containerd
systemctl disable containerd

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
apt-get install -y kubelet=1.20.11-00 kubeadm=1.20.11-00 kubectl=1.20.11-00
apt-mark hold kubelet kubeadm kubectl

#------------- create a cluster
touch /home/$user_name/k8s_log.sh /home/$user_name/k8s_join_master.sh /home/$user_name/k8s_join_worker.sh
chmod a+x /home/$user_name/k8s_log.sh /home/$user_name/k8s_join_master.sh /home/$user_name/k8s_join_worker.sh

kubeadm init --control-plane-endpoint "${ip}:6443" --upload-certs --pod-network-cidr "10.244.0.0/16" >> /home/$user_name/k8s_log.sh

cat << EOF >> /home/$user_name/k8s_join_master.sh
#!/bin/bash
$(sed -n '/kubeadm join/,/control/p' /home/$user_name/k8s_log.sh | head -n 3)
EOF

cat << EOF >> /home/$user_name/k8s_join_worker.sh
#!/bin/bash
$(sed -n '/kubeadm join/,/control/p' /home/$user_name/k8s_log.sh | tail -n 2)
EOF

#------------- enable kubectl in any accounts
mkdir -p /home/$user_name/.kube
cp -i /etc/kubernetes/admin.conf /home/$user_name/.kube/config
chown $user_name:$user_name /home/$user_name/.kube/config

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

#------------- enable kubectl & kubeadm auto-completion
echo "source <(kubectl completion bash)" >> /home/$user_name/.bashrc
echo "source <(kubeadm completion bash)" >> /home/$user_name/.bashrc

echo "source <(kubectl completion bash)" >> $HOME/.bashrc
echo "source <(kubeadm completion bash)" >> $HOME/.bashrc
source $HOME/.bashrc

#------------- install CNI network addon
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

#------------- enable ssh connection && open port 80
apt install openssh-server
ufw allow 22
ufw allow 80

#------------- allow specific ports for k8s
ufw allow 6443
ufw allow 2379
ufw allow 2380
ufw allow 10250
ufw allow 10251
ufw allow 10252
systemctl enable ufw
systemctl start ufw
ufw enable

#------------- install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 \
  && chmod 700 get_helm.sh \
  && ./get_helm.sh
