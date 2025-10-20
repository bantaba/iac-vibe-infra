// Virtual Network Manager module
// This module implements Virtual Network Manager with network groups and connectivity configurations
// for centralized network management and security policy enforcement

targetScope = 'resourceGroup'

// Import shared modules
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

@description('The name of the Virtual Network Manager')
param virtualNetworkManagerName string

@description('The description of the Virtual Network Manager')
param description string = 'Virtual Network Manager for centralized network governance'

@description('The scope of the Virtual Network Manager')
@allowed(['Subscription', 'ManagementGroup'])
param scopeType string = 'Subscription'

@description('The scope access type for the Virtual Network Manager')
@allowed(['SecurityAdmin', 'Connectivity'])
param scopeAccesses array = ['SecurityAdmin', 'Connectivity']

@description('The subscription ID or management group ID for the scope')
param scopeId string

@description('Network groups configuration')
param networkGroups array = [
  {
    name: 'production-web-tier'
    description: 'Production web tier virtual networks'
    memberType: 'VirtualNetwork'
  }
  {
    name: 'production-business-tier'
    description: 'Production business tier virtual networks'
    memberType: 'VirtualNetwork'
  }
  {
    name: 'production-data-tier'
    description: 'Production data tier virtual networks'
    memberType: 'VirtualNetwork'
  }
  {
    name: 'staging-environment'
    description: 'Staging environment virtual networks'
    memberType: 'VirtualNetwork'
  }
  {
    name: 'development-environment'
    description: 'Development environment virtual networks'
    memberType: 'VirtualNetwork'
  }
]

@description('Connectivity configurations for network topology')
param connectivityConfigurations array = [
  {
    name: 'hub-spoke-connectivity'
    description: 'Hub and spoke connectivity configuration'
    connectivityTopology: 'HubAndSpoke'
    isGlobal: false
    deleteExistingPeering: false
    hubs: []
    appliesToGroups: []
  }
]

@description('Security admin configurations')
param securityAdminConfigurations array = [
  {
    name: 'default-security-rules'
    description: 'Default security admin rules for all network groups'
    applyOnNetworkIntentPolicyBasedServices: ['None']
    ruleCollections: [
      {
        name: 'deny-high-risk-ports'
        description: 'Deny access to high-risk ports'
        appliesToGroups: []
        rules: [
          {
            name: 'deny-rdp-from-internet'
            description: 'Deny RDP access from internet'
            access: 'Deny'
            direction: 'Inbound'
            priority: 100
            protocol: 'Tcp'
            sources: [
              {
                addressPrefixType: 'IPPrefix'
                addressPrefix: 'Internet'
              }
            ]
            destinations: [
              {
                addressPrefixType: 'IPPrefix'
                addressPrefix: '*'
              }
            ]
            sourcePortRanges: ['*']
            destinationPortRanges: ['3389']
          }
          {
            name: 'deny-ssh-from-internet'
            description: 'Deny SSH access from internet'
            access: 'Deny'
            direction: 'Inbound'
            priority: 110
            protocol: 'Tcp'
            sources: [
              {
                addressPrefixType: 'IPPrefix'
                addressPrefix: 'Internet'
              }
            ]
            destinations: [
              {
                addressPrefixType: 'IPPrefix'
                addressPrefix: '*'
              }
            ]
            sourcePortRanges: ['*']
            destinationPortRanges: ['22']
          }
        ]
      }
    ]
  }
]

@description('Tags to apply to all resources')
param tags TagConfiguration

@description('Location for the Virtual Network Manager')
param location string = resourceGroup().location

// Virtual Network Manager resource
resource virtualNetworkManager 'Microsoft.Network/networkManagers@2023-09-01' = {
  name: virtualNetworkManagerName
  location: location
  tags: tags
  properties: {
    description: description
    networkManagerScopes: {
      subscriptions: scopeType == 'Subscription' ? [scopeId] : []
      managementGroups: scopeType == 'ManagementGroup' ? [scopeId] : []
    }
    networkManagerScopeAccesses: scopeAccesses
  }
}

// Network Groups
resource networkGroupResources 'Microsoft.Network/networkManagers/networkGroups@2023-09-01' = [for group in networkGroups: {
  name: group.name
  parent: virtualNetworkManager
  properties: {
    description: group.description
  }
}]

// Connectivity Configurations
resource connectivityConfigurationResources 'Microsoft.Network/networkManagers/connectivityConfigurations@2023-09-01' = [for config in connectivityConfigurations: {
  name: config.name
  parent: virtualNetworkManager
  properties: {
    description: config.description
    connectivityTopology: config.connectivityTopology
    isGlobal: config.isGlobal
    deleteExistingPeering: config.deleteExistingPeering
    hubs: config.hubs
    appliesToGroups: config.appliesToGroups
  }
  dependsOn: networkGroupResources
}]

// Security Admin Configurations
resource securityAdminConfigurationResources 'Microsoft.Network/networkManagers/securityAdminConfigurations@2023-09-01' = [for config in securityAdminConfigurations: {
  name: config.name
  parent: virtualNetworkManager
  properties: {
    description: config.description
    applyOnNetworkIntentPolicyBasedServices: config.applyOnNetworkIntentPolicyBasedServices
  }
  dependsOn: networkGroupResources
}]

// Security Admin Rule Collections
resource securityAdminRuleCollections 'Microsoft.Network/networkManagers/securityAdminConfigurations/ruleCollections@2023-09-01' = [for (config, configIndex) in securityAdminConfigurations: {
  name: '${config.name}/${config.ruleCollections[0].name}'
  parent: securityAdminConfigurationResources[configIndex]
  properties: {
    description: config.ruleCollections[0].description
    appliesToGroups: config.ruleCollections[0].appliesToGroups
  }
}]

// Security Admin Rules
resource securityAdminRules 'Microsoft.Network/networkManagers/securityAdminConfigurations/ruleCollections/rules@2023-09-01' = [for (config, configIndex) in securityAdminConfigurations: {
  name: '${config.name}/${config.ruleCollections[0].name}/${config.ruleCollections[0].rules[0].name}'
  parent: securityAdminRuleCollections[configIndex]
  properties: {
    description: config.ruleCollections[0].rules[0].description
    access: config.ruleCollections[0].rules[0].access
    direction: config.ruleCollections[0].rules[0].direction
    priority: config.ruleCollections[0].rules[0].priority
    protocol: config.ruleCollections[0].rules[0].protocol
    sources: config.ruleCollections[0].rules[0].sources
    destinations: config.ruleCollections[0].rules[0].destinations
    sourcePortRanges: config.ruleCollections[0].rules[0].sourcePortRanges
    destinationPortRanges: config.ruleCollections[0].rules[0].destinationPortRanges
  }
}]

// Additional security admin rules for SSH blocking
resource securityAdminRulesSSH 'Microsoft.Network/networkManagers/securityAdminConfigurations/ruleCollections/rules@2023-09-01' = [for (config, configIndex) in securityAdminConfigurations: {
  name: '${config.name}/${config.ruleCollections[0].name}/${config.ruleCollections[0].rules[1].name}'
  parent: securityAdminRuleCollections[configIndex]
  properties: {
    description: config.ruleCollections[0].rules[1].description
    access: config.ruleCollections[0].rules[1].access
    direction: config.ruleCollections[0].rules[1].direction
    priority: config.ruleCollections[0].rules[1].priority
    protocol: config.ruleCollections[0].rules[1].protocol
    sources: config.ruleCollections[0].rules[1].sources
    destinations: config.ruleCollections[0].rules[1].destinations
    sourcePortRanges: config.ruleCollections[0].rules[1].sourcePortRanges
    destinationPortRanges: config.ruleCollections[0].rules[1].destinationPortRanges
  }
}]

// Outputs
@description('The resource ID of the Virtual Network Manager')
output virtualNetworkManagerId string = virtualNetworkManager.id

@description('The name of the Virtual Network Manager')
output virtualNetworkManagerName string = virtualNetworkManager.name

@description('The resource IDs of the network groups')
output networkGroupIds array = [for (group, index) in networkGroups: networkGroupResources[index].id]

@description('The names of the network groups')
output networkGroupNames array = [for group in networkGroups: group.name]

@description('The resource IDs of the connectivity configurations')
output connectivityConfigurationIds array = [for (config, index) in connectivityConfigurations: connectivityConfigurationResources[index].id]

@description('The resource IDs of the security admin configurations')
output securityAdminConfigurationIds array = [for (config, index) in securityAdminConfigurations: securityAdminConfigurationResources[index].id]