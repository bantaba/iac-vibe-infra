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
// SECURITY MODULES
// ========================================

// Deploy Key Vault
module keyVault 'modules/security/key-vault.bicep' = {
  name: 'key-vault-deployment'
  params: {
    keyVaultName: namingConventions.outputs.namingConvention.keyVault
    keyVaultConfig: {
      sku: environmentConfig.skuTier == 'Premium' ? 'premium' : 'standard'
      enableSoftDelete: true
      softDeleteRetentionInDays: environment == 'prod' ? 90 : 30
      enablePurgeProtection: environment == 'prod'
      enableRbacAuthorization: true
      networkAcls: {
        bypass: 'AzureServices'
        defaultAction: environmentConfig.enablePrivateEndpoints ? 'Deny' : 'Allow'
        ipRules: []
        virtualNetworkRules: environmentConfig.enablePrivateEndpoints ? [
          virtualNetwork.outputs.subnetIds.management
          virtualNetwork.outputs.subnetIds.webTier
          virtualNetwork.outputs.subnetIds.businessTier
        ] : []
      }
    }
    keyVaultAdministrators: []
    keyVaultSecretsUsers: []
    keyVaultCertificateUsers: []
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
  ]
}

// ========================================
// COMPUTE MODULES
// ========================================

// Deploy Availability Sets (for environments not using scale sets)
module webTierAvailabilitySet 'modules/compute/availability-sets.bicep' = if (!environmentConfig.enableHighAvailability) {
  name: 'web-tier-availability-set-deployment'
  params: {
    availabilitySetName: '${namingConventions.outputs.namingConvention.availabilitySet}-web'
    tier: 'web'
    faultDomainCount: 2
    updateDomainCount: 5
    useManagedDisks: true
    createProximityPlacementGroup: false
    tags: tags
    location: location
  }
}

module businessTierAvailabilitySet 'modules/compute/availability-sets.bicep' = if (!environmentConfig.enableHighAvailability) {
  name: 'business-tier-availability-set-deployment'
  params: {
    availabilitySetName: '${namingConventions.outputs.namingConvention.availabilitySet}-business'
    tier: 'business'
    faultDomainCount: 2
    updateDomainCount: 5
    useManagedDisks: true
    createProximityPlacementGroup: false
    tags: tags
    location: location
  }
}

// Deploy VM Scale Sets for Web Tier
module webTierVmScaleSet 'modules/compute/virtual-machines.bicep' = {
  name: 'web-tier-vmss-deployment'
  params: {
    vmScaleSetName: '${namingConventions.outputs.namingConvention.virtualMachineScaleSet}-web'
    subnetId: virtualNetwork.outputs.subnetIds.webTier
    loadBalancerBackendAddressPoolIds: []
    applicationGatewayBackendAddressPoolIds: []
    vmConfig: {
      vmSize: environmentConfig.virtualMachineSize
      osType: 'Linux'
      osDisk: {
        storageAccountType: environmentConfig.skuTier == 'Premium' ? 'Premium_LRS' : 'Standard_LRS'
        diskSizeGB: 128
      }
      dataDisks: []
      networkInterface: {
        enableAcceleratedNetworking: environmentConfig.skuTier != 'Basic'
        enableIpForwarding: false
      }
      availability: {
        availabilitySetId: null
        availabilityZone: null
      }
    }
    tier: 'web'
    instanceCount: environmentConfig.instanceCount
    enableAutoscaling: environmentConfig.enableHighAvailability
    minInstanceCount: 1
    maxInstanceCount: environmentConfig.enableHighAvailability ? (environmentConfig.instanceCount * 3) : environmentConfig.instanceCount
    availabilityZones: environmentConfig.enableHighAvailability ? ['1', '2', '3'] : ['1']
    adminUsername: 'azureuser'
    sshPublicKey: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7S...' // This should come from Key Vault in production
    customScriptExtension: {}
    enableBootDiagnostics: true
    networkSecurityGroupId: networkSecurityGroups.outputs.nsgIds.webTier
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
    networkSecurityGroups
  ]
}

// Deploy VM Scale Sets for Business Tier
module businessTierVmScaleSet 'modules/compute/virtual-machines.bicep' = {
  name: 'business-tier-vmss-deployment'
  params: {
    vmScaleSetName: '${namingConventions.outputs.namingConvention.virtualMachineScaleSet}-business'
    subnetId: virtualNetwork.outputs.subnetIds.businessTier
    loadBalancerBackendAddressPoolIds: []
    applicationGatewayBackendAddressPoolIds: []
    vmConfig: {
      vmSize: environmentConfig.virtualMachineSize
      osType: 'Linux'
      osDisk: {
        storageAccountType: environmentConfig.skuTier == 'Premium' ? 'Premium_LRS' : 'Standard_LRS'
        diskSizeGB: 128
      }
      dataDisks: [
        {
          diskSizeGB: 256
          storageAccountType: environmentConfig.skuTier == 'Premium' ? 'Premium_LRS' : 'Standard_LRS'
          lun: 0
        }
      ]
      networkInterface: {
        enableAcceleratedNetworking: environmentConfig.skuTier != 'Basic'
        enableIpForwarding: false
      }
      availability: {
        availabilitySetId: null
        availabilityZone: null
      }
    }
    tier: 'business'
    instanceCount: environmentConfig.instanceCount
    enableAutoscaling: environmentConfig.enableHighAvailability
    minInstanceCount: 1
    maxInstanceCount: environmentConfig.enableHighAvailability ? (environmentConfig.instanceCount * 2) : environmentConfig.instanceCount
    availabilityZones: environmentConfig.enableHighAvailability ? ['1', '2', '3'] : ['1']
    adminUsername: 'azureuser'
    sshPublicKey: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7S...' // This should come from Key Vault in production
    customScriptExtension: {}
    enableBootDiagnostics: true
    networkSecurityGroupId: networkSecurityGroups.outputs.nsgIds.businessTier
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
    networkSecurityGroups
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

// Security outputs
output security object = {
  keyVault: {
    id: keyVault.outputs.keyVaultId
    name: keyVault.outputs.keyVaultName
    uri: keyVault.outputs.keyVaultUri
    config: keyVault.outputs.keyVaultConfig
  }
}

// Compute outputs
output compute object = {
  availabilitySets: {
    webTier: !environmentConfig.enableHighAvailability ? {
      id: webTierAvailabilitySet.outputs.availabilitySetId
      name: webTierAvailabilitySet.outputs.availabilitySetName
      config: webTierAvailabilitySet.outputs.availabilitySetConfig
    } : {
      id: ''
      name: ''
      config: {}
    }
    businessTier: !environmentConfig.enableHighAvailability ? {
      id: businessTierAvailabilitySet.outputs.availabilitySetId
      name: businessTierAvailabilitySet.outputs.availabilitySetName
      config: businessTierAvailabilitySet.outputs.availabilitySetConfig
    } : {
      id: ''
      name: ''
      config: {}
    }
  }
  virtualMachineScaleSets: {
    webTier: {
      id: webTierVmScaleSet.outputs.vmScaleSetId
      name: webTierVmScaleSet.outputs.vmScaleSetName
      config: webTierVmScaleSet.outputs.vmScaleSetConfig
      autoscaleSettingsId: webTierVmScaleSet.outputs.autoscaleSettingsId
    }
    businessTier: {
      id: businessTierVmScaleSet.outputs.vmScaleSetId
      name: businessTierVmScaleSet.outputs.vmScaleSetName
      config: businessTierVmScaleSet.outputs.vmScaleSetConfig
      autoscaleSettingsId: businessTierVmScaleSet.outputs.autoscaleSettingsId
    }
  }
}