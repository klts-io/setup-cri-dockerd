#!/usr/bin/env bash

# Copyright 2022 The KTLS Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

function goarch() {
    local arch
    arch="$(uname -m)"

    case "${arch}" in
    x86_64 | amd64 | x64)
        echo "amd64"
        ;;
    armv8* | aarch64* | arm64)
        echo "arm64"
        ;;
    *)
        echo "${arch}"
        ;;
    esac
}

function usage() {
    echo "Usage: install.sh [options]"
    echo "Options:"
    echo "  --force: force install"
    echo "  --help: print this help"
}

function args() {
    local help=0

    while [[ $# -gt 0 ]]; do
        case "${1}" in
        --force)
            FORCE=Y
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: ${1}"
            usage
            exit 1
            ;;
        esac
        shift
    done
}

VERSION=${VERSION:-v0.2.0}
FORCE=${FORCE:-n}

BIN_URL="https://github.com/Mirantis/cri-dockerd/releases/download/${VERSION}/cri-dockerd-${VERSION}-linux-$(goarch).tar.gz"
CRI_SOCK="unix:///var/run/cri-dockerd.sock"
KUBEADM_FLAGS_ENV="/var/lib/kubelet/kubeadm-flags.env"

SERVICE_NAME="cri-docker.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
TAR_NAME="cri-dockerd.tar.gz"
TAR_PATH="${TMPDIR:-/tmp/}/install-cri-dockerd"
BIN_NAME="cri-dockerd"
BIN_PATH="/usr/local/bin"
OLD_FLAGS=$(cat "${KUBEADM_FLAGS_ENV}")

function check_container_runtime_of_kubelet() {
    if [[ "${OLD_FLAGS}" =~ "--container-runtime=remote" ]]; then
        echo cat "${KUBEADM_FLAGS_ENV}"
        cat "${KUBEADM_FLAGS_ENV}"
        echo "The container runtime is already set to remote"
        echo "Please check the container runtime of kubelet"
        exit 1
    fi
}

function download() {
    local url=$1
    local output=$2
    echo "Downloading ${url} to ${output}"
    if command -v wget >/dev/null; then
        wget -O "${output}" "${url}"
    elif command -v curl >/dev/null; then
        curl -L -o "${output}" "${url}"
    else
        echo "Neither wget nor curl is installed"
        exit 1
    fi
}

function install_cri_dockerd() {
    if [[ ! -x "${BIN_PATH}/${BIN_NAME}" ]]; then
        echo "Installing cri-dockerd"
        if [[ ! -s "${TAR_PATH}/${TAR_NAME}" ]]; then
            mkdir -p "${TAR_PATH}" && download "${BIN_URL}" "${TAR_PATH}/${TAR_NAME}"
        fi
        tar -xzvf "${TAR_PATH}/${TAR_NAME}" -C "${BIN_PATH}" "${BIN_NAME}" && chmod +x "${BIN_PATH}/${BIN_NAME}"
        echo "Binary of cri-dockerd is installed"
    else
        echo "Binary of cri-dockerd already installed"
    fi

    echo "${BIN_PATH}/${BIN_NAME}" --version
    "${BIN_PATH}/${BIN_NAME}" --version || {
        echo "Failed to install cri-dockerd"
        exit 1
    }
}

function filter_kubelet_args() {
    local arg
    local out=()
    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "${arg}" in
        --cni-bin-dir | --cni-bin-dir=*)
            [[ "${arg#*=}" != "${arg}" ]] && out+=("--cni-bin-dir=${arg#*=}") || { out+=("--cni-bin-dir=${2}") && shift; }
            shift
            ;;
        --cni-cache-dir | --cni-cache-dir=*)
            [[ "${arg#*=}" != "${arg}" ]] && out+=("--cni-cache-dir=${arg#*=}") || { out+=("--cni-cache-dir=${2}") && shift; }
            shift
            ;;
        --cni-conf-dir | --cni-conf-dir=*)
            [[ "${arg#*=}" != "${arg}" ]] && out+=("--cni-conf-dir=${arg#*=}") || { out+=("--cni-conf-dir=${2}") && shift; }
            shift
            ;;
        --image-pull-progress-deadline | --image-pull-progress-deadline=*)
            [[ "${arg#*=}" != "${arg}" ]] && out+=("--image-pull-progress-deadline=${arg#*=}") || { out+=("--image-pull-progress-deadline=${2}") && shift; }
            shift
            ;;
        --log-level | --log-level=*)
            [[ "${arg#*=}" != "${arg}" ]] && out+=("--log-level=${arg#*=}") || { out+=("--log-level=${2}") && shift; }
            shift
            ;;
        --network-plugin | --network-plugin=*)
            [[ "${arg#*=}" != "${arg}" ]] && out+=("--network-plugin=${arg#*=}") || { out+=("--network-plugin=${2}") && shift; }
            shift
            ;;
        --network-plugin-mtu | --network-plugin-mtu=*)
            [[ "${arg#*=}" != "${arg}" ]] && out+=("--network-plugin-mtu=${arg#*=}") || { out+=("--network-plugin-mtu=${2}") && shift; }
            shift
            ;;
        --pod-cidr | --pod-cidr=*)
            [[ "${arg#*=}" != "${arg}" ]] && out+=("--pod-cidr=${arg#*=}") || { out+=("--pod-cidr=${2}") && shift; }
            shift
            ;;
        --pod-infra-container-image | --pod-infra-container-image=*)
            [[ "${arg#*=}" != "${arg}" ]] && out+=("--pod-infra-container-image=${arg#*=}") || { out+=("--pod-infra-container-image=${2}") && shift; }
            shift
            ;;
        --runtime-cgroups | --runtime-cgroups=*)
            [[ "${arg#*=}" != "${arg}" ]] && out+=("--runtime-cgroups=${arg#*=}") || { out+=("--runtime-cgroups=${2}") && shift; }
            shift
            ;;
        *)
            shift
            ;;
        esac
    done
    echo "${out[@]}"
}

function start_cri_dockerd() {
    source "${KUBEADM_FLAGS_ENV}"
    cat <<EOF >"${SERVICE_PATH}"
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/cri-dockerd --cri-dockerd-root-directory=/var/lib/dockershim --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin --container-runtime-endpoint=${CRI_SOCK} $(filter_kubelet_args ${KUBELET_KUBEADM_ARGS})
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutSec=0
RestartSec=2
Restart=always

StartLimitBurst=3

StartLimitInterval=60s

LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}" --now
    systemctl status --no-pager "${SERVICE_NAME}" || {
        echo "Failed to start cri-dockerd"
        exit 1
    }

    echo "crictl --runtime-endpoint "${CRI_SOCK}" ps"
    crictl --runtime-endpoint "${CRI_SOCK}" ps
}

function configure_kubelet() {
    NEW_FLAGS=$(echo "${OLD_FLAGS%\"*} --container-runtime=remote --container-runtime-endpoint=${CRI_SOCK}\"")

    case "${FORCE}" in
    [yY][eE][sS] | [yY])
        : # Skip
        ;;
    *)

        echo "============== The original kubeadm-flags.env =============="
        echo cat "${KUBEADM_FLAGS_ENV}"
        cat "${KUBEADM_FLAGS_ENV}"
        echo "================ Configure kubelet ========================="
        echo "cp ${KUBEADM_FLAGS_ENV} ${KUBEADM_FLAGS_ENV}.bak"
        echo "cat <<EOF > ${KUBEADM_FLAGS_ENV}"
        echo "${NEW_FLAGS}"
        echo "EOF"
        echo "systemctl daemon-reload"
        echo "systemctl restart kubelet"
        echo "============================================================"
        echo "Please double check the configuration of kubelet"
        echo "Next will execute the that command"
        echo "If you don't need this prompt process, please run:"
        echo "    $0 --force"
        echo "============================================================"

        read -r -p "Are you sure? [y/n] " response
        case "$response" in
        [yY][eE][sS] | [yY])
            : # Skip
            ;;
        *)
            echo "You no enter 'y', so abort install now"
            echo "but the cri-dockerd is installed and running"
            echo "if need is uninstall the cri-dockerd please run:"
            echo "   systemctl stop ${SERVICE_NAME}"
            echo "   systemctl disable ${SERVICE_NAME}"
            echo "   rm ${SERVICE_PATH}"
            echo "   rm ${BIN_PATH}/${BIN_NAME}"
            exit 1
            ;;
        esac
        ;;
    esac

    cp "${KUBEADM_FLAGS_ENV}" "${KUBEADM_FLAGS_ENV}.bak"
    cat <<EOF >${KUBEADM_FLAGS_ENV}
${NEW_FLAGS}
EOF
    systemctl daemon-reload
    systemctl restart kubelet
}

function main() {
    args "$@"
    check_container_runtime_of_kubelet
    install_cri_dockerd
    start_cri_dockerd
    configure_kubelet
}

main "$@"
