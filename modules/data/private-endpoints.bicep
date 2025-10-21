// Private Endpoints module
// This module creates private endpoint configurations for SQL Database and Storage
// with DNS integration and network connectivity
//
// Features:
// - Supports multiple Azure services (SQL Database, Storage Account, Key Vault, etc.)
// - Automatic private DNS zone creation and virtual network linking
// - Support for existing private DNS zones
// - Custom DNS server configuration
// - Comprehensive outputs for integration with other modules
//
// Usage Example:
// module privateEndpoints 'modules/data/private-endpoints.bicep' = {
//   name: 'private-endpoints-deployment'
//   params: {
//     privateEndpointNamePrefix: 'contoso-webapp-prod'
//     subnetId: '/subscriptions/.../subnets/data-tier'
//     virtualNetworkId: '/subscriptions/.../virtualNetworks/vnet'
//     privateEndpointConfigs: [
//       {
//         name: 'sql-server'
//         privateLinkServiceId: sqlServer.outputs.sqlServerId
//         groupId: 'sqlServer'
//       }
//       {
//         name: 'storage-blob'
//         privateLinkServiceId: storageAccount.outputs.storageAccountId
//         groupId: 'storageBlob'
//       }
//     ]
//     enablePrivateDnsZones: true
//     tags: tags
//     location: location
//   }
// }

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
param privateEndpointConfigs {
  name: string
  privateLinkServiceId: string
  groupId: 'sqlServer' | 'storageBlob' | 'storageFile' | 'storageQueue' | 'storageTable' | 'storageWeb' | 'storageDfs' | 'keyVault' | 'cosmosDb' | 'serviceBus' | 'eventHub' | 'redis' | 'cognitiveServices' | 'search' | 'monitor' | 'oms' | 'ods' | 'agentsvc'
}[] = []

// DNS configuration parameters
@description('Enable private DNS zone creation and linking')
param enablePrivateDnsZones bool = true

@description('Existing private DNS zone resource IDs (if not creating new ones)')
param existingPrivateDnsZoneIds object = {}

@description('Custom DNS servers for private DNS zones')
param customDnsServers array = []

@description('Enable custom DNS configuration for private endpoints')
param enableCustomDnsConfiguration bool = false

// Variables for DNS zone names using environment() function for cloud compatibility
var privateDnsZoneNames = {
  sqlServer: 'privatelink${environment().suffixes.sqlServerHostname}'
  storageBlob: 'privatelink.blob.${environment().suffixes.storage}'
  storageFile: 'privatelink.file.${environment().suffixes.storage}'
  storageQueue: 'privatelink.queue.${environment().suffixes.storage}'
  storageTable: 'privatelink.table.${environment().suffixes.storage}'
  storageWeb: 'privatelink.web.${environment().suffixes.storage}'
  storageDfs: 'privatelink.dfs.${environment().suffixes.storage}'
  keyVault: 'privatelink${environment().suffixes.keyvaultDns}'
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
    customDnsConfigs: enableCustomDnsConfiguration && length(customDnsServers) > 0 ? [
      {
        fqdn: privateDnsZoneNames[config.groupId]
        ipAddresses: customDnsServers
      }
    ] : []
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
  dnsZoneName: privateDnsZoneNames[config.groupId]
  connectionState: 'Approved'
}]

@description('Private DNS zone names')
output privateDnsZoneNames object = privateDnsZoneNames

@description('Private endpoint network interface details')
output networkInterfaceDetails array = [for (config, index) in privateEndpointConfigs: {
  name: config.name
  networkInterfaceId: privateEndpoints[index].properties.networkInterfaces[0].id
  privateIpAddress: ''
  subnetId: subnetId
}]

// Variable for DNS zone virtual network links
var dnsZoneVnetLinksArray = [for (config, index) in privateEndpointConfigs: {
  name: config.name
  groupId: config.groupId
  dnsZoneName: privateDnsZoneNames[config.groupId]
  vnetLinkId: enablePrivateDnsZones ? privateDnsZoneVnetLinks[index].id : ''
  registrationEnabled: false
}]

@description('Private DNS zone virtual network links')
output dnsZoneVnetLinks array = enablePrivateDnsZones ? dnsZoneVnetLinksArray : []

@description('Summary of private endpoint deployment')
output deploymentSummary object = {
  totalEndpoints: length(privateEndpointConfigs)
  enabledPrivateDnsZones: enablePrivateDnsZones
  customDnsConfiguration: enableCustomDnsConfiguration
  subnetId: subnetId
  virtualNetworkId: virtualNetworkId
  supportedServicesCount: length(items(privateDnsZoneNames))
}