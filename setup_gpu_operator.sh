#!/bin/bash

# this will create 
# (1) nvidia driver daemonset
# (2) nvidia container toolkit daemonset
# (3) nvidia cuda daemonset
# (4) nvidia dcgm exporter
# (5) nvidia operator feature discovery
# (6) nvidia operator validator
# (7) nvidia gpu feature discovery
# (8) nvidia device plugin
# (9) nvidia mig manager

# add NVIDIA Helm repository
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia \
  && helm repo update

helm install --wait --generate-name \
     -n gpu-operator --create-namespace \
     nvidia/gpu-operator

# uninstall gpu-operator : helm delete -n gpu-operator $(helm list -n gpu-operator | grep gpu-operator | awk '{print $1}')
