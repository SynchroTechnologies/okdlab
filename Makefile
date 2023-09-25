# Set environment variables
export INSTALLER_URL=https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.12/openshift-install-linux.tar.gz
export CLIENT_URL=https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.12/openshift-client-linux.tar.gz

export RESOURCE_GROUP_BASE_NAME?=ocp-labandreani-rg
export LOCATION?=canadacentral

export STORAGE_ACCOUNT_NAME?=andocplab0sa01
export STORAGE_ACCOUNT_CONTAINER?=vhd

export SERVICE_PRINCIPAL_NAME?=ocp-ipi-sp

export DNS_ZONE_NAME?=ocplab.ha.ar

export TAG_CONTACT?=hugo.antolini@synchro-technologies.com
export TAG_ENV?=LAB
export TAG_DATE?=$(shell date +%Y-%m-%d)

## export FCOS_IMAGE_VERSION=
## export FCOS_IMAGE_URL=

## export OPENSHIFT_INSTALL_OS_IMAGE_OVERRIDE=https://$(STORAGE_ACCOUNT_NAME).blob.core.windows.net/$(STORAGE_ACCOUNT_CONTAINER)/fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd


.DEFAULT_GOAL := help


validate-logged-to-azure:  ## Validate if you are logged to Azure
	@az account show > /dev/null 2>&1 || (echo "You are not logged to Azure. Please run 'az login' first." && exit 1)

help:  ## This help
	@grep -hE '^[A-Za-z0-9_ \-]*?:.*##.*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-35s\033[0m %s\n", $$1, $$2}'

azure-list-resourcegroups: validate-logged-to-azure  ## List resource groups in Azure
	@echo
	@echo 'Azure Account: ' $(shell az account show --query 'name' -o tsv)
	@echo '----------------------------------'
	@az group list --output table

azure-vm-status: validate-logged-to-azure ## List VMs status
	@echo
	@echo 'Azure Account: ' $(shell az account show --query 'name' -o tsv)
	@echo '----------------------------------'
	@az vm list -d -o table --query "[].{name:name, status:powerState}"

azure-vm-start: validate-logged-to-azure ## Start lab VMs
	@echo
	@echo 'Azure Account: ' $(shell az account show --query 'name' -o tsv)
	@echo '----------------------------------'
	@az vm start --ids $(shell az vm list -d --query "[].id" -o tsv)

azure-vm-stop: validate-logged-to-azure ## Stop lab VMs
	@echo
	@echo 'Azure Account: ' $(shell az account show --query 'name' -o tsv)
	@echo '----------------------------------'
	@az vm deallocate --ids $(shell az vm list -d --query "[].id" -o tsv)

azure-deploy-base-rg: validate-logged-to-azure  ## Create base resource group with public dns needed for OKD IPI Install
	@echo
	@echo 'Creating resource group: ' $(RESOURCE_GROUP_NAME)
	@echo '----------------------------------'
	@az group create --name $(RESOURCE_GROUP_BASE_NAME) \
	                 --location $(LOCATION) \
					 --tags "CONTACT=$(TAG_CONTACT) ENV=$(TAG_ENV) DATE=$(TAG_DATE)" \
					 --output table
					 
	@az deployment group create --resource-group $(RESOURCE_GROUP_BASE_NAME) \
	                            --template-file ./templates/lab-baserg.bicep \
								--parameters dnsZoneName=$(DNS_ZONE_NAME) \
								--parameters strgAccName=$(STORAGE_ACCOUNT_NAME) \
								--output table 

azure-deploy-rbac-serviceprincipal: ## Deploy RBAC and Service Principal
	@echo
	@echo 'Deploying RBAC Service Principal for OKD IPI Install'
	@echo '----------------------------------'
	az ad sp create-for-rbac --name $(SERVICE_PRINCIPAL_NAME) \
	                          --role "Contributor" \
							  --scopes /subscriptions/$(shell az account show --query 'id' -o tsv) \
							  --years 3 \
							  --output json > ./installer/$(SERVICE_PRINCIPAL_NAME).json
							  
	az role assignment create --role "User Access Administrator" \
	                           --assignee $(shell jq -r '.appId' ./installer/*sp.json) \
							   --scope /subscriptions/$(shell az account show --query 'id' -o tsv) \
							   --output table

azure-upload-vhd: ## Upload FCOS vhd image to storage account in Azure
	@echo
	@echo 'Uploading FCOS vhd image to storage account in Azure'
	@echo '----------------------------------'
	@az storage blob upload --account-name $(STORAGE_ACCOUNT_NAME) \
	                        --container-name $(STORAGE_ACCOUNT_CONTAINER) \
							--name fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd \
							--file ./installer/fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd \
							--type page \
							--output table

openshift-get-installer:  ## Get OCP installer
	@echo
	@echo 'Getting OCP installer'
	@echo '----------------------------------'
	@-mkdir ./installer
	@cd installer && \
	wget $(INSTALLER_URL) -O ocp-install.tar.gz && \
	tar -xvf ocp-install.tar.gz && \
	rm ocp-install.tar.gz README.md

openshift-get-oc:  ## Get OCP command line client
	@echo
	@echo 'Getting OCP installer'
	@echo '----------------------------------'
	@-mkdir ./installer
	@cd installer && \
	wget $(CLIENT_URL) -O ocp-client.tar.gz && \
	tar -xvf ocp-client.tar.gz && \
	rm ocp-client.tar.gz README.md

openshift-get-fcos-image: ## Get Fedora CoreOS Image for Azure
	@echo
	@echo 'Getting Fedora CoreOS Image for Azure'
	@echo '----------------------------------'
	@-mkdir ./installer
	@cd ./installer && \
	 wget $(FCOS_IMAGE_URL) -O ./fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd.xz && \
	 unxz ./fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd.xz

openshift-create-install-config: ## Create Openshift Installer Manifests
	@echo
	@echo 'Creating Openshift Installer configuration'
	@echo '----------------------------------'
	@./installer/openshift-install create install-config --dir=./installer/ipi-install

openshift-create-cluster:  ## Create Openshift Cluster
	@echo
	@echo 'Creating Openshift Cluster'
	@echo '----------------------------------'
	@./installer/openshift-install create cluster --dir=./installer/ipi-install
