// Parameters
param location string = resourceGroup().location
param dnsZoneName string = 'okd.synchro.ar'
param strgAccName string = 'synstrgacc0okdlab00'
param containerName string = 'vhd'
param tags object = resourceGroup().tags

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: dnsZoneName
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
  tags: tags
}

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: strgAccName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
  tags: tags
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: sa
}

resource vhdContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  name: containerName
  parent: blobService
  properties: {
    publicAccess: 'Container'
  }
}
