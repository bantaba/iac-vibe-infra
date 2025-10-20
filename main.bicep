// Main orchestration template for Azure Bicep Infrastructure
// This template coordinates the deployment of all infrastructure modules

targetScope = 'resourceGroup'

// Import shared modules
import { EnvironmentConfig, TagConfiguration } from 'modules/shared/parameter-schemas.bicep'

// Common parameters
@description('The prefix for all resource names')
param resourcePrefix string

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('The Azure region for deployment')
param location string = resourceGroup().location

@description('The workload or application name')
param workloadName string

@description('Tags to apply to all resources')
param tags TagConfiguration = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
  CostCenter: 'IT'
  Owner: 'DevOps-Team'
  Project: 'Azure-Bicep-Infrastructure'
  DeploymentDate: utcNow('yyyy-MM-dd')
}

// Environment-specific configuration
@description('Environment-specific configuration settings')
param environmentConfig EnvironmentConfig

// Deploy naming convention utilities
module namingConventions 'modules/shared/naming-conventions.bicep' = {
  name: 'naming-conventions'
  params: {
    resourcePrefix: resourcePrefix
    environment: environment
    workloadName: workloadName
  }
}

// Deploy common variables and constants
module commonVariables 'modules/shared/common-variables.bicep' = {
  name: 'common-variables'
}

// ========================================
// NETWORKING MODULES
// ========================================

// Deploy DDoS Protection Plan (if enabled)
module ddosProtection 'modules/networking/ddos-protection.bicep' = if (environmentConfig.enableDdosProtection) {
  name: 'ddos-protection-deployment'
  params: {
    ddosProtectionPlanName: namingConventions.outputs.namingConvention.ddosProtectionPlan
    tags: tags
    location: location
    enableDdosProtection: environmentConfig.enableDdosProtection
    enableTelemetry: true
  }
}

// Deploy Network Security Groups
module networkSecurityGroups 'modules/networking/network-security-groups.bicep' = {
  name: 'network-security-groups-deployment'
  params: {
    nsgNamePrefix: namingConventions.outputs.namingConvention.networkSecurityGroup
    tags: tags
    location: location
    vnetAddressSpace: environmentConfig.networkAddressSpace
    applicationGatewaySubnet: environmentConfig.subnets.applicationGateway
    managementSubnet: environmentConfig.subnets.management
    webTierSubnet: environmentConfig.subnets.webTier
    businessTierSubnet: environmentConfig.subnets.businessTier
    dataTierSubnet: environmentConfig.subnets.dataTier
    activeDirectorySubnet: environmentConfig.subnets.activeDirectory
  }
}

// Deploy Virtual Network with subnets
module virtualNetwork 'modules/networking/virtual-network.bicep' = {
  name: 'virtual-network-deployment'
  params: {
    virtualNetworkName: namingConventions.outputs.namingConvention.virtualNetwork
    addressSpace: [environmentConfig.networkAddressSpace]
    subnets: environmentConfig.subnets
    tags: tags
    location: location
    enableDdosProtection: environmentConfig.enableDdosProtection
    ddosProtectionPlanId: environmentConfig.enableDdosProtection ? ddosProtection.outputs.ddosProtectionPlanId : null
    networkSecurityGroups: networkSecurityGroups.outputs.nsgIds
  }
  dependsOn: environmentConfig.enableDdosProtection ? [
    networkSecurityGroups
    ddosProtection
  ] : [
    networkSecurityGroups
  ]
}

// Deploy Virtual Network Manager
module virtualNetworkManager 'modules/networking/vnet-manager.bicep' = {
  name: 'virtual-network-manager-deployment'
  params: {
    virtualNetworkManagerName: namingConventions.outputs.namingConvention.virtualNetworkManager
    vnmDescription: 'Virtual Network Manager for ${workloadName} ${environment} environment'
    scopeType: 'Subscription'
    scopeAccesses: ['SecurityAdmin', 'Connectivity']
    scopeId: subscription().subscriptionId
    tags: tags
    location: location
    networkGroups: [
      {
        name: '${environment}-web-tier'
        description: '${environment} web tier virtual networks'
        memberType: 'VirtualNetwork'
      }
      {
        name: '${environment}-business-tier'
        description: '${environment} business tier virtual networks'
        memberType: 'VirtualNetwork'
      }
      {
        name: '${environment}-data-tier'
        description: '${environment} data tier virtual networks'
        memberType: 'VirtualNetwork'
      }
    ]
    connectivityConfigurations: [
      {
        name: '${environment}-hub-spoke-connectivity'
        description: 'Hub and spoke connectivity for ${environment} environment'
        connectivityTopology: 'HubAndSpoke'
        isGlobal: false
        deleteExistingPeering: false
        hubs: []
        appliesToGroups: []
      }
    ]
    securityAdminConfigurations: [
      {
        name: '${environment}-security-rules'
        description: 'Security admin rules for ${environment} environment'
        applyOnNetworkIntentPolicyBasedServices: ['None']
        ruleCollections: [
          {
            name: 'deny-high-risk-ports'
            description: 'Deny access to high-risk ports from internet'
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
  }
  dependsOn: [
    virtualNetwork
  ]
}

// ========================================
// OUTPUTS
// ========================================

// Core outputs
output namingConvention object = namingConventions.outputs.namingConvention
output deploymentTags TagConfiguration = tags
output environmentConfig EnvironmentConfig = environmentConfig
output commonVariables object = commonVariables.outputs
output resourcePrefix string = resourcePrefix
output environment string = environment
output workloadName string = workloadName
output location string = location

// Networking outputs
output networking object = {
  virtualNetwork: {
    id: virtualNetwork.outputs.virtualNetworkId
    name: virtualNetwork.outputs.virtualNetworkName
    addressSpace: virtualNetwork.outputs.addressSpace
    subnets: {
      ids: virtualNetwork.outputs.subnetIds
      names: virtualNetwork.outputs.subnetNames
      addressPrefixes: virtualNetwork.outputs.subnetAddressPrefixes
    }
  }
  networkSecurityGroups: {
    ids: networkSecurityGroups.outputs.nsgIds
    names: networkSecurityGroups.outputs.nsgNames
  }
  ddosProtection: environmentConfig.enableDdosProtection ? {
    id: ddosProtection.outputs.ddosProtectionPlanId
    name: ddosProtection.outputs.ddosProtectionPlanName
    config: ddosProtection.outputs.ddosProtectionConfig
  } : {
    id: ''
    name: ''
    config: {
      id: ''
      enabled: false
    }
  }
  virtualNetworkManager: {
    id: virtualNetworkManager.outputs.virtualNetworkManagerId
    name: virtualNetworkManager.outputs.virtualNetworkManagerName
    networkGroups: {
      ids: virtualNetworkManager.outputs.networkGroupIds
      names: virtualNetworkManager.outputs.networkGroupNames
    }
    connectivityConfigurations: virtualNetworkManager.outputs.connectivityConfigurationIds
    securityAdminConfigurations: virtualNetworkManager.outputs.securityAdminConfigurationIds
  }
}