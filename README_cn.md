# setup-cri-dockerd

这个项目是 [cri-dockerd](https://github.com/Mirantis/cri-dockerd) 的安装卸载脚本

可以非常方便的从 Docker shim 切换到 CRI Dockerd 和回退, Pod 不会重启

- [English](https://github.com/klts-io/setup-cri-dockerd/blob/main/README.md)
- [简体中文](https://github.com/klts-io/setup-cri-dockerd/blob/main/README_cn.md)

## 要求

使用 Kubeadm 安装的 Kubernetes

相关参数都在 `/var/lib/kubelet/kubeadm-flags.env` 配置 如 (`--network-plugin`, `--pod-infra-container-image`)

## 从 Docker Shim 切换到 CRI Dockerd
``` bash
wget -O install.sh https://raw.githubusercontent.com/klts-io/setup-cri-dockerd/main/install.sh
chmod +x ./install.sh && ./install.sh
```

## 回退
``` bash
wget -O uninstall.sh https://raw.githubusercontent.com/klts-io/setup-cri-dockerd/main/uninstall.sh
chmod +x ./uninstall.sh && ./uninstall.sh
```
