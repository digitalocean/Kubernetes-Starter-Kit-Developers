#!/bin/bash

#This script is used to install the prerequisites for using tvk one-click plugin

echo "##### Installing krew package #####"

(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

echo "##### Verifying krew package installation #####"

kubectl krew

echo "##### Installing requests package #####"

pip3 install requests

echo "##### Installing s3cmd package #####"

apt install s3cmd -y

echo "##### Installing yq package #####"

snap install yq

echo "##### Installing tvk-plugins/tvk-preflight using krew package #####"

kubectl krew index add tvk-plugins https://github.com/trilioData/tvk-plugins.git

kubectl krew install tvk-plugins/tvk-preflight

echo "##### Installing tvk-plugins/tvk-oneclick using krew package #####"

kubectl krew install tvk-plugins/tvk-oneclick

echo ""
echo "##### Now, you can run below command with options: #####"
echo ""
echo "kubectl tvk-onclick"
echo ""
echo "-n    Non-interactive TVK install, TVK UI configuration, create target, "
echo "      and run sample backup operation. You also need to update the input_config file"
echo "-i    Interactive installation of TVK Operator and TVK Manager"
echo "-c    Interactive configuration of TVK Management UI"
echo "-t    Interactive creation of target using NFS/S3 supported storage option to be used as backup repository"
echo "-s    Interactively run a sample backup operation"
echo "-i -c -t -s   to interactively perform all above operations in single command"
echo ""
echo ""
