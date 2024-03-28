#!/bin/bash

# Install Azure CLI
# (Taken from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Docker CE
# (Taken from https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add current user to docker group
# (Taken from https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user)
sudo usermod -aG docker $USER

# Install kubectl
# (Taken from https://kubernetes.io/de/docs/tasks/tools/install-kubectl/#installieren-der-kubectl-anwendung-mithilfe-der-systemeigenen-paketverwaltung)
sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# Install helm
# (Taken from https://helm.sh/docs/intro/install/#from-apt-debianubuntu)
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install -y helm