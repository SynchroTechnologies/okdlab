# Set environment variables
export RESOURCE_GROUP_BASE_NAME?=okd-lab-base-rg
export LOCATION?=canadacentral

export OKD_INSTALLER_URL=https://github.com/okd-project/okd/releases/download/4.10.0-0.okd-2022-05-28-062148/openshift-install-linux-4.10.0-0.okd-2022-05-28-062148.tar.gz
export OKD_CLIENT_URL=https://github.com/okd-project/okd/releases/download/4.10.0-0.okd-2022-05-28-062148/openshift-client-linux-4.10.0-0.okd-2022-05-28-062148.tar.gz
export FCOS_IMAGE_VERSION=35.20220327.3.0
export FCOS_IMAGE_URL=https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/$(FCOS_IMAGE_VERSION)/x86_64/fedora-coreos-$(FCOS_IMAGE_VERSION)-azure.x86_64.vhd.xz

.DEFAULT_GOAL := help


validate-logged-to-azure:  ## Validate if you are logged to Azure
	@az account show > /dev/null 2>&1 || (echo "You are not logged to Azure. Please run 'az login' first." && exit 1)

help:  ## This help
	@grep -hE '^[A-Za-z0-9_ \-]*?:.*##.*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

list-resources: validate-logged-to-azure  ## List resources
	@echo
	@echo 'Azure Account: ' $(shell az account show --query 'name' -o tsv)
	@echo '----------------------------------'
	@az group list --output table

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
