# Setup instructions for THALES' Luna Key Broker for DKE

Instructions and small scripts/samples to ease the deployment of THALES' Luna Key Broker for DKE on Microsoft's AKS.

## About Double Key Encryption (DKE)

DKE is the next generation of Microsoft's HYOK concept. By using it you can encrypt your most sensitve files in a way that only your selected entities can read/decrypt them. The reason why organisations implement it is to prevent Microsoft or any other US departments behind from accessing files stored and processed within Microsoft's cloud environment.

Read more about the details of DKE at [the official Microsoft docs](https://docs.microsoft.com/en-us/microsoft-365/compliance/double-key-encryption?view=o365-worldwide).

## Architecture of this setup

### DKE Service

... will be based on the Luna Key Broker for DKE. This solution exposes an HTTP endpoint with the defined REST methods required by DKE clients. It is bundled in a docker image and within this setup we are going to deploy it on a kubernetes cluster. On the k8s cluster we will facilitate NGINX and letsencrypt as ingress setup to handle the incoming HTTPS requests.

The crypto backend will be a DPoD service (Data Protection on Demand), which is a simple Cloud-based HSM from THALES.

As kubernetes platform we will be using Azure Kubernetes Services (AKS).

### Microsoft 365 and Information Protection Service

This guide assumes that you already have a working Microsoft 365 environment with Information Protection enabled and some users having the required licenses to use the feature. There is not really much choice in this setup.

### Microsoft 365 Client

... will be a simple Windows 10 Pro/Enterprise VM (either hosted in any cloud or any onprem hypervisor), which has access to the internet.

In this guide we will setup the VM within Azure.

### Management/admin host

... will be a linux box with the required tooling installed to controll the kubernetes cluster and the Azure resources.

In this guide we will setup the box as an Ubuntu Server VM within Azure.

## Prerequisites

Follow the steps below to create a small demo environment containing...

* A Windows 10/11 machine as a Microsoft 365 client
* an instance of the THALES solution powering a DKE service hosted on Microsoft's AKS
* a configured Information Protection label for DKE

### THALES components

To be able to setup the THALES solution, you will need to approach a THALES sales representative or engineer in order for them to share the current docker image and an instance of an HSMonDemand service from the THALES Cloud service "DPoD" (Data Protection on Demand).

### Microsoft components

If you do not have a working Microsoft 365 tenant yet, it is possible to sign up at the [Microsoft 365 Developer Program](https://developer.microsoft.com/en-us/microsoft-365/dev-program) to get a free sandbox with the required user licenses. **A setup of such an account will not be covered in this guide!**

### Hosting

To host the DKE service via the Luna Key Broker image you need any container runtime. In this guide we will use Microsoft's AKS as kubernetes provider. Although this is not a good idea for production environments since the DKE service should be deployed outside the realms of Microsoft, we use it due to its easy availability for most existing Microsoft customers. For recommendations for production use see the [Security section](/SECURITY.md) of this repository.

It is required to have the DKE service available for your clients under a FQDN without any prepended paths (<https://fqdn/path-extension/> is not allowed). So we need a dedicated DNS entry for our DKE service. Please make sure to have a free DNS record ready which we can later assign to the IP exposed by the AKS. Also the FQDN must be under a verified *Custom Domain* of EntraID in order to receive proper ID-tokens to authenticate users.

**Be aware that this will cause you monthly costs around 200 bucks, if you choose the same cluster size as in this guide!**

## Instructions

### 0. Before you begin

A checklist of what you need and what will be used in this guide:

* The container image of THALES' Luna Key Broker for DKE as a tar ball. This guide assumes version 1.2.
* Access to a DPoD tenant to create a DPoD service. Else you can request your THALES contact to share details to an existing service.
* Free DNS name for your DKE service
  * *lkb-on.azure.gegenleitner.eu* will be used.
  * In the past it was possible to use an Azure provided DNS-Entry. Now it is required to use a FQDN that ends in a trusted "Custom Domain" in AzureAD.
* Azure account capable of deploying azure resources
* Working M365 tenant
* Tool for SSH-ing into your Ubuntu Server (i. e. putty) on your workstation
* Tool for SSH-Copy files to your Ubuntu Server (i. e. WinSCP, scp or pscp) on your workstation
  * *WinSCP* will be used
* RDP-Client on your workstation to access the Windows test machine
  * Standard *Remote Desktop Connection* from Windows 10 will be used

### 1. Prepare your Azure environment

Watch this small video ([link](https://youtu.be/45EN6CySi9c)) to setup all required resources:

* New dedicated resource group (*luna-key-broker-demo*)
* Ubuntu Server 22.04 LTS (*management-linux*)
* AKS cluster with ACR (*dke-cluster* and *dkerepository*)
  * *dkerepository* for ACR might be shown as taken, because this must be a unique name across Azure. If this is the case, just select another name (required changes will be noted in the guide later)
* Windows 10/11 client (*dke-client*)

#### Install required software on Ubuntu

Follow the steps below or just copy-paste them into an open SSH-session on your Ubuntu Server:

```shell
# Change into your user's home directory
cd ~
# Ensure git is installed
sudo apt-get update && sudo apt-get install -y git unzip
# Checkout this git repository to have all scripts at hand
git clone https://github.com/ThalesGroup/dke-service-setup.git
# Call the installer script to get all required tools onto your management machine
chmod +x ~/dke-service-setup/mgmt-linux/install_tooling.sh
~/dke-service-setup/mgmt-linux/install_tooling.sh
# Create a few directories to organize your tooling
mkdir -p ~/hsm
mkdir -p ~/k8s
```

### 2. Prepare your CloudHSM

#### Create a service client to a new CloudHSM service

Watch the video ([link](https://youtu.be/3AuSA94XaaE)) on how to create a new HSMonDemand service client on DPoD. Additional information can be found at <https://thalesdocs.com/dpod/services/hsmod_services/hsmod_add_service/index.html>.

#### Initialize CloudHSM and its roles

Copy the service client (*setup-lkb.zip*) via scp onto the Ubuntu server into */home/azureuser/hsm* and open a SSH-session to the host into this directory. Then follow the commands from below to setup the service. Additional information can be found at <https://thalesdocs.com/dpod/services/hsmod_services/hsmod_linux_client/index.html>.

```shell
# Change into the hsm directory
cd ~/hsm
# Unpack the setup package
unzip ./setup-lkb.zip
# Unpack the linux client
tar xvf cvclient-min.tar
# Configure environment
source ./setenv
# Start the hsm configuration tool "lunacm"
# If the command executes with no errors, your connection is working correctly.
./bin/64/lunacm
```

The following commands must be called in the context of the lunacm cli tool. In this guide we will use a fixed set of passwords in order to make mapping of them to config files easier. Usually they are called interactively by not suppling passwords as parameters. Then the commands will prompt you for them. **Use your own custom secrets in a production environment!**

```shell
# Initialize the partition. During this process the cloning domain and
# Partition Security Officer (PO/SO) credentials are set (both to the passphrase "qwertzu")
partition init -label lkb-hsm -password qwertzu -domain qwertzu -force
# Login as Partition Security Officer
role login -name po -password qwertzu
# Initialize the Crypto Officer
role init -name co -password yxcvbnm
# Logout and log back in as Crypto Officer
role logout
role login -name co -password yxcvbnm
# Change password of Crypto Officer in order to unlock him
# The password will be changed to "asdfghj"
role changepw -name co -oldpw yxcvbnm -newpw asdfghj -force
# Initialize the Crypto User (ReadOnly-UserAccount)
role init -name cu -password mnbvcxy
# Logout and log back in a Crypto User
role logout
role login -name cu -password mnbvcxy
# Change password of Crypto User in order to unlock him
# The password will be changed to "jhgfdsa"
role changepw -name cu -oldpw mnbvcxy -newpw jhgfdsa -force
# Close lunacm
exit
```

Finally copy over the file *Chrystoki.conf* to your kubernetes folder as this contains the connection details for your DKE service to access the Cloud HSM.

```shell
# Change into the HSM directory to the working Chrystoki.conf
cd ~/hsm
# Copy the file to the kubernetes directory
cp ./Chrystoki.conf ~/k8s
# Change into the kubernetes directory
cd ~/k8s
# Apply a few path corrections to the file to fit the paths in the docker image later
sed -i '/LibUNIX64/s/.*/LibUNIX64 = \/usr\/safenet\/lunaclient\/libs\/64\/libCryptoki2_64.so;/' ./Chrystoki.conf
sed -i '/PluginModuleDir/s/.*/PluginModuleDir = \/usr\/safenet\/lunaclient\/plugins;/' ./Chrystoki.conf
sed -i '/LibUNIX =/d' ./Chrystoki.conf
sed -i '/LibUNIX64/a LibUNIX = /usr/safenet/lunaclient/libs/64/libCryptoki2.so;' ./Chrystoki.conf
```

#### Create some keys for DKE

With the new Crypto Officer it is possible to generate a few keys on the Cloud HSM. The setup ships with an own Certificate Management Utility (cmu) binary that helps creating asymmetric key pairs on THALES HSMs. Use the command below to generate a key with the label "DKE-Key-001" on the HSM via a SSH session on the Ubuntu server.

If you need more than one key for your DKE enabled labels later, just rename the key label in the last command to something else and run all commands again.

```shell
# Change into the hsm directory
cd ~/hsm
# (Optional) if you opened a new SSH session, configure the environment again
source ./setenv
# Generate a unique/random key identifier in the form of a50f7b86372b441ba77cb6f8598f1e35
KEY_ID=$(head -c16 </dev/urandom|xxd -p -u)
# Generate a key pair with the Certificate Management Utility
# -modulusBits=2048               DKE currently only supports RSA 2048 keys
# -publicExponent=65537           Kind of default for RSA keys
# -label=DKE-Key-001              Set the label of the key. This will be used later to reference it during creation of sensitivity labels
# -encrypt/decrypt/wrap/unwrap    Set permissions on this key's usage
# -id=$KEY_ID                     Set the key id to identify this key pair after a key rotation
# -mech=pkcs                      RSA key generation mechanism to be used
# -password=asdfghj               Define the Crypto Officer password to authenticate against the HSM service (if not defined, the command will prompt for it)
./bin/64/cmu generatekeypair -modulusBits=2048 -publicExponent=65537 -label=DKE-Key-001 -encrypt=1 -decrypt=1 -wrap=1 -unwrap=1 -id=$KEY_ID -mech=pkcs -password asdfghj
# List the available Keys. It shall output two objects with the label "DKE-Key-001"
./bin/64/cmu list -password asdfghj
```

Now the HSM is fully functional and ready to be used for DKE!

### 3. Deploy the DKE service on kubernetes

This repository ships with a few .yml templates that help setup a Key-Broker cluster on kubernetes. Follow the instructions below to create a cluster via an SSH session from the Ubuntu server. To be able to upload later THALES' docker image, upload it (you get it from THALES) from your workstation to the Ubuntu server via SCP to the directory */home/azureuser/k8s*.

```shell
####
# Define a few constants before we start setting up the dke service cluster
####
# Please take a look at https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-how-to-find-tenant
# on how to find your tenant id
TENANT_ID="YOUR_TENANT_ID"
# Update this variable with the name of your actual ACR resource created in step#1
ACR_NAME="dkerepository"
# Update this variable with the FQDN you chose for your DKE service.
DKE_SERVICE_FQDN="lkb-on.azure.gegenleitner.eu"
# Mail address for letsencrypt. There you will get notified when the cluster certs will expire.
# Please update to your own address
CERT_MASTER="my.mailing@address.org"

# Authenticate the Azure CLI to your subscription where you deployed your AKS resource.
# This will display instructions on how to authenticate your device with your Azure account
az login
# Fetch credentials for your AKS and ACR resources
# This is necessary to later have access via docker for pushing the
# image to the registry and controlling AKS via kubectl and helm
az aks get-credentials --resource-group luna-key-broker-demo --name dke-cluster
az acr login --name $ACR_NAME

####
# Import the docker image from THALES and push it to your ACR resource
####
cd ~/k8s
# Upload the CentOS-based Docker image from the Thales support portal to the current folder
unzip 610-000862-002_SW_Docker_Image_Luna_Key_Broker_for_Microsoft_DKE_centos7_v1.2.0.zip

# Import the docker image to your local docker registry
docker load -i 610-000862-002_SW_Docker_Image_Luna_Key_Broker_for_Microsoft_DKE_centos7_v1.2.0/luna-key-broker-for-dke-centos7_v1.2.0.tar
# Tag the docker image and push it to your ACR
docker tag luna-key-broker-for-dke-centos7:v1.2.0 $ACR_NAME.azurecr.io/luna-key-broker-for-dke-centos7:v1.2.0
docker push $ACR_NAME.azurecr.io/luna-key-broker-for-dke-centos7:v1.2.0

####
# Create kubernetes resources on AKS
####
# Copy all resources/templates from this repository into your kubernetes directory
cp ~/dke-service-setup/dke-service/* .

# Create a namespace for your dke service resources
kubectl create namespace dke

# (refer to https://learn.microsoft.com/en-us/azure/aks/ingress-basic?tabs=azure-cli on how to deploy ingress-nginx on AKS)
# Add the ingress-nginx repository to your local helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
# Use Helm to deploy an NGINX ingress controller
# (The last line is only required on AKS clusters. Can be omitted on other k8s clusters. See https://github.com/Azure/AKS/issues/2903 fpr explainations)
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace dke \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
  --set controller.service.externalTrafficPolicy=Local

####
# Query the public IP of the cluster's ingress for setting up DNS
####
# Get the public IP of the cluster ingress by quering the services.
# The EXTERNAL-IP of the service "ingress-nginx-controller" must be set
# as an A-Record for the chosen FQDN of your DKE service.
kubectl get services --namespace dke

# Now is the best time to configure your DNS to point the domain selected for
# DKE_SERVICE_FQDN to the EXTERNAL-IP printed by the previous command.

# Create Secrets/Configs by uploading the previously created credentials and templates
# Upload the Chrystoki.conf so that the LunaKeyBroker can connect to the Cloud HSM
kubectl create secret generic luna-config-file --from-file=Chrystoki.conf --namespace dke
# Upload the Crypto User password to grant the LunaKeyBroker access to the crypto material on the Cloud HSM
kubectl create secret generic credentials --from-literal=password='jhgfdsa' --namespace dke
# Upload a set of policies which define which user has access to which keys
# The policy syntax is from the OpenPolicyAgent Framework. Take a look at https://www.openpolicyagent.org/ to read more about it.
# The policies defined here grant every user access who holds an JWT containing a UPN value
kubectl create secret generic auth-claim --from-file=opa_policies.rego --namespace dke

# Install cert-manager as described at https://cert-manager.io/docs/installation/#default-static-install
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

# Finally deploy custom kubernetes resources via yaml files.

# Tweak the cluster issuer template to contain your mail address for cert expiry notifications
sed -i "s/YOUR_MAIL_ADDRESS/$CERT_MASTER/g" cluster-issuer.yml
# Create the cluster issuer who is responsible of issuing valid certificates to your ingress nodes
kubectl apply -f cluster-issuer.yml

# Tweak the key-broker template to fit your variables
sed -i "s/YOUR_ACR_RESOURCE/$ACR_NAME/g" luna-key-broker.yml
sed -i "s/YOUR_DKE_SERVICE_FQDN/$DKE_SERVICE_FQDN/g" luna-key-broker.yml
sed -i "s/YOUR_TENANT_ID/$TENANT_ID/g" luna-key-broker.yml
# Deploy the Key-Broker
kubectl apply -f luna-key-broker.yml --namespace dke

# Tweak the ingress template to contain the correct FQDN
sed -i "s/YOUR_DKE_SERVICE_FQDN/$DKE_SERVICE_FQDN/g" ingress.yml
# Deploy an ingress route
kubectl apply -f ingress.yml --namespace dke

```

To finally set a DNS record to map your chosen FQDN to the now available public IP, go to your DNS provider to do this.

Now your DKE service is reachable over your selected FQDN. Browse to *<https://YOUR_FQDN/DKE-Key-001>* and you should see a json response containing the details of your DKE key. **Please be patient with letsencrypt! It usually takes about 2-5 minutes to issue a publicly valid certificate to your DKE service!**

### 4. Register the DKE service in Entra ID

Better shown in a video: Watch [here](https://youtu.be/wgxUbJK9mBw) to see how you should integrate your deployed DKE service with your Azure AD in order to.

Values you need for copy-pasting are...

* The scope for the exposed API. This is called *user_impersonation* and will be appended to your service's FQDN in the WebUI.
* Authorized client applications
  * *c00e9d32-3c8d-4a7d-832b-029040e7db99* which is the ID of the Office Suite
  * *d3590ed6-52b3-4102-aeff-aad2292ab01c* which is the ID of the Azure Information Protection Unified Labeling Client **(not required anymore when using builtin labeling)**

### 5. Configure a Information Protection Label with DKE

Better shown in a video: Watch [here](https://youtu.be/BduP1CHd_58) to see how to create DKE protected labels for your users in the Microsoft 365 Security and Compliance Center.

### 6a. Configure a Windows 11 Client for DKE with Builtin-Labeling

Better shown in a video: Watch [here](https://youtu.be/OozJySbx_PU) to see how to setup your Windows 11 clients to able to use DKE labels to protect your most sensitive data.

### 6b. Configure a Windows 10 Client for DKE with AIP (legacy integrarion)

Better shown in a video: Watch [here](https://youtu.be/DLyN8L5zwCA) to see how to setup your Windows 10 clients to be able to use DKE labels to protect your most sensitive data.

To apply the required registry modifications, you can also use the [.reg file](client/Enable_DKE.reg) within this repository.
