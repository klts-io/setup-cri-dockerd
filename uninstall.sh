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

KUBEADM_FLAGS_ENV="/var/lib/kubelet/kubeadm-flags.env"
SERVICE_PATH="/etc/systemd/system/cri-docker.service"

if [[ ! -f "${KUBEADM_FLAGS_ENV}.bak" ]] ; then
    echo "Backing up ${KUBEADM_FLAGS_ENV} is not found"
    echo 1    
fi

cp "${KUBEADM_FLAGS_ENV}.bak" "${KUBEADM_FLAGS_ENV}"

systemctl daemon-reload
systemctl restart kubelet

systemctl disable cri-docker.service
systemctl stop cri-docker.service

rm -rf "${SERVICE_PATH}"
