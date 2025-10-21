// Private Endpoints module
// This module creates private endpoint configurations for SQL Database and Storage
// with DNS integration and network connectivity

targetScope = 'resourceGroup'

// Import shared types
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

// Core parameters
@description('The name prefix for private endpoints')
param privateEndpointNamePrefix string

@description('The Azure region for deployment')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags TagConfiguration

// Network configuration parameters
@description('Subnet ID where private endpoints will be created')
param subnetId string

@description('Virtual Network ID for DNS zone linking')
param virtualNetworkId string

// Private endpoint configurations
@description('Private endpoint configurations')
param privateEndpointConfigs array = []

// DNS configuration parameters
@description('Enable private DNS zone creation and linking')
param enablePrivateDnsZones bool = true

@description('Existing private DNS zone resource IDs (if not creating new ones)')
param existingPrivateDnsZoneIds object = {}

@description('Custom DNS servers for private DNS zones')
param customDnsServers array = []

// Variables for DNS zone names
var privateDnsZoneNames = {
  sqlServer: 'privatelink.database.windows.net'
  storageBlob: 'privatelink.blob.core.windows.net'
  storageFile: 'privatelink.file.core.windows.net'
  storageQueue: 'privatelink.queue.core.windows.net'
  storageTable: 'privatelink.table.core.windows.net'
  storageWeb: 'privatelink.web.core.windows.net'
  storageDfs: 'privatelink.dfs.core.windows.net'
  keyVault: 'privatelink.vaultcore.azure.net'
  cosmosDb: 'privatelink.documents.azure.com'
  serviceBus: 'privatelink.servicebus.windows.net'
  eventHub: 'privatelink.servicebus.windows.net'
  redis: 'privatelink.redis.cache.windows.net'
  cognitiveServices: 'privatelink.cognitiveservices.azure.com'
  search: 'privatelink.search.windows.net'
  monitor: 'privatelink.monitor.azure.com'
  oms: 'privatelink.oms.opinsights.azure.com'
  ods: 'privatelink.ods.opinsights.azure.com'
  agentsvc: 'privatelink.agentsvc.azure-automation.net'
}

// Create private DNS zones for each service type
resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for (config, index) in privateEndpointConfigs: if (enablePrivateDnsZones && !contains(existingPrivateDnsZoneIds, config.groupId)) {
  name: privateDnsZoneNames[config.groupId]
  location: 'global'
  tags: tags
  properties: {}
}]

// Link private DNS zones to virtual network
resource privateDnsZoneVnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (config, index) in privateEndpointConfigs: if (enablePrivateDnsZones && !contains(existingPrivateDnsZoneIds, config.groupId)) {
  parent: privateDnsZones[index]
  name: '${config.groupId}-vnet-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}]

// Create private endpoints
resource privateEndpoints 'Microsoft.Network/privateEndpoints@2023-05-01' = [for (config, index) in privateEndpointConfigs: {
  name: '${privateEndpointNamePrefix}-${config.name}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${config.name}-connection'
        properties: {
          privateLinkServiceId: config.privateLinkServiceId
          groupIds: [
            config.groupId
          ]
          requestMessage: 'Private endpoint connection for ${config.name}'
        }
      }
    ]
    customNetworkInterfaceName: '${privateEndpointNamePrefix}-${config.name}-nic'
    ipConfigurations: []
  }
}]

// Create private DNS zone groups for automatic DNS registration
resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = [for (config, index) in privateEndpointConfigs: if (enablePrivateDnsZones) {
  parent: privateEndpoints[index]
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: config.groupId
        properties: {
          privateDnsZoneId: contains(existingPrivateDnsZoneIds, config.groupId) ? existingPrivateDnsZoneIds[config.groupId] : privateDnsZones[index].id
        }
      }
    ]
  }
}]

// Outputs
@description('Private endpoint resource IDs')
output privateEndpointIds array = [for (config, index) in privateEndpointConfigs: {
  name: config.name
  id: privateEndpoints[index].id
  networkInterfaceId: privateEndpoints[index].properties.networkInterfaces[0].id
  customDnsConfigs: privateEndpoints[index].properties.customDnsConfigs
}]

@description('Private DNS zone resource IDs')
output privateDnsZoneIds array = [for (config, index) in privateEndpointConfigs: enablePrivateDnsZones ? (contains(existingPrivateDnsZoneIds, config.groupId) ? existingPrivateDnsZoneIds[config.groupId] : privateDnsZones[index].id) : '']

@description('Private endpoint configuration details')
output privateEndpointConfigs array = [for (config, index) in privateEndpointConfigs: {
  name: config.name
  id: privateEndpoints[index].id
  groupId: config.groupId
  privateLinkServiceId: config.privateLinkServiceId
  networkInterfaceId: privateEndpoints[index].properties.networkInterfaces[0].id
  privateIpAddress: length(privateEndpoints[index].properties.customDnsConfigs) > 0 ? privateEndpoints[index].properties.customDnsConfigs[0].ipAddresses[0] : ''
  fqdn: length(privateEndpoints[index].properties.customDnsConfigs) > 0 ? privateEndpoints[index].properties.customDnsConfigs[0].fqdn : ''
  dnsZoneId: enablePrivateDnsZones ? (contains(existingPrivateDnsZoneIds, config.groupId) ? existingPrivateDnsZoneIds[config.groupId] : privateDnsZones[index].id) : ''
}]

@description('Private DNS zone names')
output privateDnsZoneNames object = privateDnsZoneNames