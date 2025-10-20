// Virtual Network and Subnet module
// This module creates virtual networks with configurable address spaces and subnets
// Supports service endpoints, delegations, and integration with Virtual Network Manager

targetScope = 'resourceGroup'

// Import shared modules
import { TagConfiguration, SubnetConfiguration } from '../shared/parameter-schemas.bicep'

@description('The name of the virtual network')
param virtualNetworkName string

@description('The address space for the virtual network')
param addressSpace array = ['10.0.0.0/16']

@description('The subnet configuration for the virtual network')
param subnets SubnetConfiguration

@description('DNS servers for the virtual network (optional)')
param dnsServers array = []

@description('Enable DDoS protection for the virtual network')
param enableDdosProtection bool = false

@description('DDoS protection plan resource ID (required if enableDdosProtection is true)')
param ddosProtectionPlanId string?

@description('Tags to apply to all resources')
param tags TagConfiguration

@description('Location for the virtual network')
param location string = resourceGroup().location

@description('Enable VM protection for the virtual network')
param enableVmProtection bool = false

@description('Network Security Group resource IDs for subnets')
param networkSecurityGroups object = {}

@description('Route table resource IDs for subnets')
param routeTables object = {}

// Define subnet configurations with service endpoints and delegations
var subnetConfigurations = [
  {
    name: 'ApplicationGatewaySubnet'
    properties: {
      addressPrefix: subnets.applicationGateway
      networkSecurityGroup: contains(networkSecurityGroups, 'applicationGateway') ? {
        id: networkSecurityGroups.applicationGateway
      } : null
      routeTable: contains(routeTables, 'applicationGateway') ? {
        id: routeTables.applicationGateway
      } : null
      serviceEndpoints: [
        {
          service: 'Microsoft.KeyVault'
          locations: ['*']
        }
        {
          service: 'Microsoft.Storage'
          locations: ['*']
        }
      ]
      delegations: []
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
  {
    name: 'ManagementSubnet'
    properties: {
      addressPrefix: subnets.management
      networkSecurityGroup: contains(networkSecurityGroups, 'management') ? {
        id: networkSecurityGroups.management
      } : null
      routeTable: contains(routeTables, 'management') ? {
        id: routeTables.management
      } : null
      serviceEndpoints: [
        {
          service: 'Microsoft.KeyVault'
          locations: ['*']
        }
        {
          service: 'Microsoft.Storage'
          locations: ['*']
        }
        {
          service: 'Microsoft.Sql'
          locations: ['*']
        }
      ]
      delegations: []
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
  {
    name: 'WebTierSubnet'
    properties: {
      addressPrefix: subnets.webTier
      networkSecurityGroup: contains(networkSecurityGroups, 'webTier') ? {
        id: networkSecurityGroups.webTier
      } : null
      routeTable: contains(routeTables, 'webTier') ? {
        id: routeTables.webTier
      } : null
      serviceEndpoints: [
        {
          service: 'Microsoft.KeyVault'
          locations: ['*']
        }
        {
          service: 'Microsoft.Storage'
          locations: ['*']
        }
        {
          service: 'Microsoft.Sql'
          locations: ['*']
        }
      ]
      delegations: []
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
  {
    name: 'BusinessTierSubnet'
    properties: {
      addressPrefix: subnets.businessTier
      networkSecurityGroup: contains(networkSecurityGroups, 'businessTier') ? {
        id: networkSecurityGroups.businessTier
      } : null
      routeTable: contains(routeTables, 'businessTier') ? {
        id: routeTables.businessTier
      } : null
      serviceEndpoints: [
        {
          service: 'Microsoft.KeyVault'
          locations: ['*']
        }
        {
          service: 'Microsoft.Storage'
          locations: ['*']
        }
        {
          service: 'Microsoft.Sql'
          locations: ['*']
        }
      ]
      delegations: []
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
  {
    name: 'DataTierSubnet'
    properties: {
      addressPrefix: subnets.dataTier
      networkSecurityGroup: contains(networkSecurityGroups, 'dataTier') ? {
        id: networkSecurityGroups.dataTier
      } : null
      routeTable: contains(routeTables, 'dataTier') ? {
        id: routeTables.dataTier
      } : null
      serviceEndpoints: [
        {
          service: 'Microsoft.KeyVault'
          locations: ['*']
        }
        {
          service: 'Microsoft.Storage'
          locations: ['*']
        }
        {
          service: 'Microsoft.Sql'
          locations: ['*']
        }
      ]
      delegations: []
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
  {
    name: 'ActiveDirectorySubnet'
    properties: {
      addressPrefix: subnets.activeDirectory
      networkSecurityGroup: contains(networkSecurityGroups, 'activeDirectory') ? {
        id: networkSecurityGroups.activeDirectory
      } : null
      routeTable: contains(routeTables, 'activeDirectory') ? {
        id: routeTables.activeDirectory
      } : null
      serviceEndpoints: [
        {
          service: 'Microsoft.KeyVault'
          locations: ['*']
        }
        {
          service: 'Microsoft.Storage'
          locations: ['*']
        }
      ]
      delegations: [
        {
          name: 'Microsoft.AAD/DomainServices'
          properties: {
            serviceName: 'Microsoft.AAD/DomainServices'
          }
        }
      ]
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
]

// Virtual Network resource
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
    dhcpOptions: empty(dnsServers) ? null : {
      dnsServers: dnsServers
    }
    subnets: subnetConfigurations
    enableDdosProtection: enableDdosProtection
    ddosProtectionPlan: enableDdosProtection && ddosProtectionPlanId != null && ddosProtectionPlanId != '' ? {
      id: ddosProtectionPlanId
    } : null
    enableVmProtection: enableVmProtection
  }
}

// Outputs
@description('The resource ID of the virtual network')
output virtualNetworkId string = virtualNetwork.id

@description('The name of the virtual network')
output virtualNetworkName string = virtualNetwork.name

@description('The address space of the virtual network')
output addressSpace array = virtualNetwork.properties.addressSpace.addressPrefixes

@description('The subnet resource IDs')
output subnetIds object = {
  applicationGateway: virtualNetwork.properties.subnets[0].id
  management: virtualNetwork.properties.subnets[1].id
  webTier: virtualNetwork.properties.subnets[2].id
  businessTier: virtualNetwork.properties.subnets[3].id
  dataTier: virtualNetwork.properties.subnets[4].id
  activeDirectory: virtualNetwork.properties.subnets[5].id
}

@description('The subnet names')
output subnetNames object = {
  applicationGateway: virtualNetwork.properties.subnets[0].name
  management: virtualNetwork.properties.subnets[1].name
  webTier: virtualNetwork.properties.subnets[2].name
  businessTier: virtualNetwork.properties.subnets[3].name
  dataTier: virtualNetwork.properties.subnets[4].name
  activeDirectory: virtualNetwork.properties.subnets[5].name
}

@description('The subnet address prefixes')
output subnetAddressPrefixes object = {
  applicationGateway: virtualNetwork.properties.subnets[0].properties.addressPrefix
  management: virtualNetwork.properties.subnets[1].properties.addressPrefix
  webTier: virtualNetwork.properties.subnets[2].properties.addressPrefix
  businessTier: virtualNetwork.properties.subnets[3].properties.addressPrefix
  dataTier: virtualNetwork.properties.subnets[4].properties.addressPrefix
  activeDirectory: virtualNetwork.properties.subnets[5].properties.addressPrefix
}