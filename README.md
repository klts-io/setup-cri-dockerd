# setup-cri-dockerd

The project is install/uninstall script of [cri-dockerd](https://github.com/Mirantis/cri-dockerd)

It is very easy to switch from Docker Shim to CRI Docker and back, Pod does not restart

- [English](https://github.com/klts-io/setup-cri-dockerd/blob/main/README.md)
- [简体中文](https://github.com/klts-io/setup-cri-dockerd/blob/main/README_cn.md)

## Requirements

Kubernetes installed using Kubeadm

The related parameters are set in `/var/lib/kubelet/kubeadm-flags.env` as follows  (`--network-plugin`, `--pod-infra-container-image`)

## Switch from Docker Shim to CRI Dockerd
``` bash
wget -O install.sh https://raw.githubusercontent.com/klts-io/setup-cri-dockerd/main/install.sh
chmod +x ./install.sh && ./install.sh
```

## Back
``` bash
wget -O uninstall.sh https://raw.githubusercontent.com/klts-io/setup-cri-dockerd/main/uninstall.sh
chmod +x ./uninstall.sh && ./uninstall.sh
```
