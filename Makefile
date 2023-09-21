# Set environment variables
export RESOURCE_GROUP_BASE_NAME?=okd-lab-base-rg
export LOCATION?=canadacentral

export STORAGE_ACCOUNT_NAME?=synstrgacc0okdlab00
export STORAGE_ACCOUNT_CONTAINER?=vhd

export OKD_INSTALLER_URL=https://github.com/okd-project/okd/releases/download/4.11.0-0.okd-2023-01-14-152430/openshift-install-linux-4.11.0-0.okd-2023-01-14-152430.tar.gz
export OKD_CLIENT_URL=https://github.com/okd-project/okd/releases/download/4.11.0-0.okd-2023-01-14-152430/openshift-client-linux-4.11.0-0.okd-2023-01-14-152430.tar.gz

export FCOS_IMAGE_VERSION=36.20220716.3.1
export FCOS_IMAGE_URL=https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/$(FCOS_IMAGE_VERSION)/x86_64/fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd.xz

export OPENSHIFT_INSTALL_OS_IMAGE_OVERRIDE=https://$(STORAGE_ACCOUNT_NAME).blob.core.windows.net/$(STORAGE_ACCOUNT_CONTAINER)/fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd


.DEFAULT_GOAL := help


validate-logged-to-azure:  ## Validate if you are logged to Azure
	@az account show > /dev/null 2>&1 || (echo "You are not logged to Azure. Please run 'az login' first." && exit 1)

help:  ## This help
	@grep -hE '^[A-Za-z0-9_ \-]*?:.*##.*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

azure-list-resources: validate-logged-to-azure  ## List resources
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

deploy-base-resource-group: validate-logged-to-azure  ## Create base resource group with public dns needed for OKD IPI Install
	@echo
	@echo 'Creating resource group: ' $(RESOURCE_GROUP_NAME)
	@echo '----------------------------------'
	@az group create --name $(RESOURCE_GROUP_BASE_NAME) \
	                 --location $(LOCATION) \
					 --output table
	@az deployment group create --resource-group $(RESOURCE_GROUP_BASE_NAME) \
	                            --template-file ./templates/okd-lab-baserg.bicep \
								--parameters ./templates/okd-lab-baserg.bicepparam \
								--output table 

get-okd-installer:  ## Get OKD installer
	@echo
	@echo 'Getting OKD installer'
	@echo '----------------------------------'
	@-mkdir ./installer
	@cd installer && \
	wget $(OKD_INSTALLER_URL) -O okd-install.tar.gz && \
	tar -xvf okd-install.tar.gz && \
	rm okd-install.tar.gz README.md

get-fcos-image: ## Get Fedora CoreOS Image for Azure
	@echo
	@echo 'Getting Fedora CoreOS Image for Azure'
	@echo '----------------------------------'
	@-mkdir ./installer
	@cd ./installer && \
	 wget $(FCOS_IMAGE_URL) -O ./fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd.xz && \
	 unxz ./fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd.xz

upload-vhd-to-azure: ## Upload FCOS vhd image to storage account in Azure
	@echo
	@echo 'Uploading FCOS vhd image to storage account in Azure'
	@echo '----------------------------------'
	@az storage blob upload --account-name $(STORAGE_ACCOUNT_NAME) \
	                        --container-name $(STORAGE_ACCOUNT_CONTAINER) \
							--name fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd \
							--file ./installer/fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd \
							--type page \
							--output table

deploy-rbac-serviceprincipal: ## Deploy RBAC and Service Principal
	@echo
	@echo 'Deploying RBAC Service Principal for OKD IPI Install'
	@echo '----------------------------------'
	@az ad sp create-for-rbac --name "okd-ipi-sp" \
	                          --role "Contributor" \
							  --scopes /subscriptions/$(shell az account show --query 'id' -o tsv) \
							  --years 3 \
							  --output json > ./installer/okd-ipi-sp.json
	@az role assignment create --role "User Access Administrator" \
	                           --assignee $(shell jq -r '.appId' ./installer/okd-ipi-sp.json) \
							   --scope /subscriptions/$(shell az account show --query 'id' -o tsv) \
							   --output table

openshift-create-install-config: ## Create Openshift Installer Manifests
	@echo
	@echo 'Creating Openshift Installer configuration'
	@echo '----------------------------------'
	@./installer/openshift-install create install-config --dir=./installer/okd-ipi-install

openshift-create-cluster:  ## Create Openshift Cluster
	@echo
	@echo 'Creating Openshift Cluster'
	@echo '----------------------------------'
	@./installer/openshift-install create cluster --dir=./installer/okd-ipi-install
