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

// Deploy Managed Identities
module managedIdentities 'modules/security/managed-identity.bicep' = {
  name: 'managed-identities-deployment'
  params: {
    managedIdentityBaseName: '${resourcePrefix}-${workloadName}-${environment}'
    userAssignedIdentities: [
      {
        name: 'application-services'
        description: 'Managed identity for application services'
        roleAssignments: []
      }
      {
        name: 'key-vault-access'
        description: 'Managed identity for Key Vault access'
        roleAssignments: []
      }
      {
        name: 'storage-access'
        description: 'Managed identity for storage account access'
        roleAssignments: []
      }
      {
        name: 'sql-access'
        description: 'Managed identity for SQL database access'
        roleAssignments: []
      }
      {
        name: 'application-gateway'
        description: 'Managed identity for Application Gateway Key Vault access'
        roleAssignments: []
      }
    ]
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '' // Will be set after Log Analytics is deployed
    enableTelemetry: true
    tags: tags
    location: location
  }
}

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
    keyVaultSecretsUsers: [
      managedIdentities.outputs.managedIdentityLookup.keyVaultAccess.principalId
      managedIdentities.outputs.managedIdentityLookup.applicationGateway.principalId
    ]
    keyVaultCertificateUsers: [
      managedIdentities.outputs.managedIdentityLookup.applicationGateway.principalId
    ]
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
    managedIdentities
  ]
}

// Deploy Azure Policy compliance (temporarily disabled due to scope issues)
// module azurePolicy 'modules/security/azure-policy.bicep' = {
//   name: 'azure-policy-deployment'
//   params: {
//     resourcePrefix: resourcePrefix
//     environment: environment
//     location: location
//     workloadName: workloadName
//     tags: tags
//     enableSecurityBenchmark: true
//     enableCustomPolicies: true
//     policyScope: 'resourceGroup'
//     complianceNotificationEmails: [] // Should be provided via parameters
//   }
// }

// Deploy security baseline configuration (temporarily disabled due to scope issues)
// module securityBaseline 'modules/security/security-baseline.bicep' = {
//   name: 'security-baseline-deployment'
//   params: {
//     resourcePrefix: resourcePrefix
//     environment: environment
//     location: location
//     workloadName: workloadName
//     tags: tags
//     logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
//     enableSecurityBaseline: true
//     enableAuditLogging: true
//     securityBaselineConfig: {
//       requireHttpsOnly: true
//       requireTlsVersion: '1.2'
//       enableAdvancedThreatProtection: true
//       requirePrivateEndpoints: environment == 'prod'
//       enableNetworkSecurityGroups: true
//       requireManagedIdentity: true
//       enableDiagnosticSettings: true
//       auditRetentionDays: environment == 'prod' ? 365 : 90
//     }
//   }
//   dependsOn: [
//     logAnalyticsWorkspace
//   ]
// }

// ========================================
// COMPUTE MODULES
// ========================================

// Deploy Public IP for Application Gateway
module applicationGatewayPublicIp 'modules/networking/public-ip.bicep' = {
  name: 'application-gateway-public-ip-deployment'
  params: {
    publicIpName: replace(namingConventions.outputs.namingConvention.publicIp, '{purpose}', 'agw')
    sku: 'Standard'
    allocationMethod: 'Static'
    domainNameLabel: '${resourcePrefix}-${workloadName}-${environment}-agw'
    zones: environmentConfig.enableHighAvailability ? ['1', '2', '3'] : ['1']
    tags: tags
    location: location
  }
}

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

// Deploy Internal Load Balancer for Business Tier
module businessTierLoadBalancer 'modules/compute/load-balancer.bicep' = {
  name: 'business-tier-load-balancer-deployment'
  params: {
    loadBalancerName: namingConventions.outputs.loadBalancerNames.business
    sku: environmentConfig.skuTier == 'Basic' ? 'Basic' : 'Standard'
    subnetId: virtualNetwork.outputs.subnetIds.businessTier
    privateIpAllocationMethod: 'Dynamic'
    tier: 'business'
    backendAddressPools: [
      {
        name: 'business-tier-pool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'business-tier-http-rule'
        frontendPort: 80
        backendPort: 80
        protocol: 'Tcp'
        enableFloatingIp: false
        idleTimeoutInMinutes: 4
        loadDistribution: 'Default'
        probeName: 'business-tier-http-probe'
      }
      {
        name: 'business-tier-https-rule'
        frontendPort: 443
        backendPort: 443
        protocol: 'Tcp'
        enableFloatingIp: false
        idleTimeoutInMinutes: 4
        loadDistribution: 'Default'
        probeName: 'business-tier-https-probe'
      }
    ]
    healthProbes: [
      {
        name: 'business-tier-http-probe'
        protocol: 'Http'
        port: 80
        requestPath: '/health'
        intervalInSeconds: 15
        numberOfProbes: 2
      }
      {
        name: 'business-tier-https-probe'
        protocol: 'Https'
        port: 443
        requestPath: '/health'
        intervalInSeconds: 15
        numberOfProbes: 2
      }
    ]
    zones: environmentConfig.enableHighAvailability ? ['1', '2', '3'] : ['1']
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
  ]
}

// Deploy Internal Load Balancer for Data Tier
module dataTierLoadBalancer 'modules/compute/load-balancer.bicep' = {
  name: 'data-tier-load-balancer-deployment'
  params: {
    loadBalancerName: namingConventions.outputs.loadBalancerNames.data
    sku: environmentConfig.skuTier == 'Basic' ? 'Basic' : 'Standard'
    subnetId: virtualNetwork.outputs.subnetIds.dataTier
    privateIpAllocationMethod: 'Dynamic'
    tier: 'data'
    backendAddressPools: [
      {
        name: 'data-tier-pool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'data-tier-sql-rule'
        frontendPort: 1433
        backendPort: 1433
        protocol: 'Tcp'
        enableFloatingIp: false
        idleTimeoutInMinutes: 4
        loadDistribution: 'Default'
        probeName: 'data-tier-tcp-probe'
      }
    ]
    healthProbes: [
      {
        name: 'data-tier-tcp-probe'
        protocol: 'Tcp'
        port: 1433
        intervalInSeconds: 15
        numberOfProbes: 2
      }
    ]
    zones: environmentConfig.enableHighAvailability ? ['1', '2', '3'] : ['1']
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
  ]
}

// Deploy Application Gateway
module applicationGateway 'modules/compute/application-gateway.bicep' = {
  name: 'application-gateway-deployment'
  params: {
    applicationGatewayName: namingConventions.outputs.namingConvention.applicationGateway
    subnetId: virtualNetwork.outputs.subnetIds.applicationGateway
    sku: environmentConfig.applicationGatewaySku
    capacity: environmentConfig.applicationGatewayCapacity
    enableAutoscaling: environmentConfig.enableHighAvailability
    minCapacity: 1
    maxCapacity: environmentConfig.enableHighAvailability ? (environmentConfig.applicationGatewayCapacity * 3) : environmentConfig.applicationGatewayCapacity
    publicIpAddressId: applicationGatewayPublicIp.outputs.publicIpAddressId
    keyVaultId: keyVault.outputs.keyVaultId
    sslCertificateName: 'ssl-certificate'
    managedIdentityId: managedIdentities.outputs.managedIdentityLookup.applicationGateway.id
    backendPools: [
      {
        name: 'web-tier-pool'
        backendAddresses: []
      }
    ]
    backendHttpSettings: [
      {
        name: 'web-tier-http-settings'
        port: 80
        protocol: 'Http'
        cookieBasedAffinity: 'Disabled'
        requestTimeout: 30
        probeName: 'web-tier-health-probe'
      }
      {
        name: 'web-tier-https-settings'
        port: 443
        protocol: 'Https'
        cookieBasedAffinity: 'Disabled'
        requestTimeout: 30
        probeName: 'web-tier-https-health-probe'
      }
    ]
    healthProbes: [
      {
        name: 'web-tier-health-probe'
        protocol: 'Http'
        host: ''
        path: '/health'
        interval: 30
        timeout: 30
        unhealthyThreshold: 3
        port: 80
      }
      {
        name: 'web-tier-https-health-probe'
        protocol: 'Https'
        host: ''
        path: '/health'
        interval: 30
        timeout: 30
        unhealthyThreshold: 3
        port: 443
      }
    ]
    httpListeners: [
      {
        name: 'http-listener'
        frontendIpConfiguration: 'public-frontend-ip'
        frontendPort: 'port-80'
        protocol: 'Http'
      }
      {
        name: 'https-listener'
        frontendIpConfiguration: 'public-frontend-ip'
        frontendPort: 'port-443'
        protocol: 'Https'
        sslCertificate: 'ssl-certificate'
      }
    ]
    requestRoutingRules: [
      {
        name: 'http-routing-rule'
        ruleType: 'Basic'
        priority: 100
        httpListener: 'http-listener'
        backendAddressPool: 'web-tier-pool'
        backendHttpSettings: 'web-tier-http-settings'
      }
      {
        name: 'https-routing-rule'
        ruleType: 'Basic'
        priority: 200
        httpListener: 'https-listener'
        backendAddressPool: 'web-tier-pool'
        backendHttpSettings: 'web-tier-https-settings'
      }
    ]
    wafConfiguration: {
      enabled: environmentConfig.applicationGatewaySku == 'WAF_v2'
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    customWafRules: []
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
    applicationGatewayPublicIp
    keyVault
    managedIdentities
  ]
}

// Deploy VM Scale Sets for Web Tier
module webTierVmScaleSet 'modules/compute/virtual-machines.bicep' = {
  name: 'web-tier-vmss-deployment'
  params: {
    vmScaleSetName: '${namingConventions.outputs.namingConvention.virtualMachineScaleSet}-web'
    subnetId: virtualNetwork.outputs.subnetIds.webTier
    loadBalancerBackendAddressPoolIds: []
    applicationGatewayBackendAddressPoolIds: [
      applicationGateway.outputs.backendAddressPoolIds['web-tier-pool']
    ]
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
    applicationGateway
  ]
}

// Deploy VM Scale Sets for Business Tier
module businessTierVmScaleSet 'modules/compute/virtual-machines.bicep' = {
  name: 'business-tier-vmss-deployment'
  params: {
    vmScaleSetName: '${namingConventions.outputs.namingConvention.virtualMachineScaleSet}-business'
    subnetId: virtualNetwork.outputs.subnetIds.businessTier
    loadBalancerBackendAddressPoolIds: [
      businessTierLoadBalancer.outputs.backendAddressPoolIds['business-tier-pool']
    ]
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
    businessTierLoadBalancer
  ]
}

// ========================================
// MONITORING MODULES
// ========================================

// Deploy Log Analytics Workspace
module logAnalyticsWorkspace 'modules/monitoring/log-analytics.bicep' = {
  name: 'log-analytics-workspace-deployment'
  params: {
    workspaceName: namingConventions.outputs.namingConvention.logAnalyticsWorkspace
    workspaceSku: environmentConfig.skuTier == 'Basic' ? 'PerGB2018' : 'PerGB2018'
    retentionInDays: environmentConfig.logRetentionDays
    dailyQuotaGb: environmentConfig.skuTier == 'Basic' ? 5 : (environmentConfig.skuTier == 'Standard' ? 10 : 50)
    enablePublicNetworkAccess: !environmentConfig.enablePrivateEndpoints
    allowedSubnetIds: environmentConfig.enablePrivateEndpoints ? [
      virtualNetwork.outputs.subnetIds.management
      virtualNetwork.outputs.subnetIds.webTier
      virtualNetwork.outputs.subnetIds.businessTier
      virtualNetwork.outputs.subnetIds.dataTier
    ] : []
    allowedIpAddresses: []
    enableDataExport: environment == 'prod'
    dataExportStorageAccountId: ''
    enableDiagnosticSettings: false
    diagnosticStorageAccountId: ''
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
  ]
}

// Update Managed Identity Diagnostics (after Log Analytics is available)
module managedIdentityDiagnostics 'modules/security/managed-identity.bicep' = {
  name: 'managed-identity-diagnostics-update'
  params: {
    managedIdentityBaseName: '${resourcePrefix}-${workloadName}-${environment}'
    userAssignedIdentities: [
      {
        name: 'application-services'
        description: 'Managed identity for application services'
        roleAssignments: []
      }
      {
        name: 'key-vault-access'
        description: 'Managed identity for Key Vault access'
        roleAssignments: []
      }
      {
        name: 'storage-access'
        description: 'Managed identity for storage account access'
        roleAssignments: []
      }
      {
        name: 'sql-access'
        description: 'Managed identity for SQL database access'
        roleAssignments: []
      }
      {
        name: 'application-gateway'
        description: 'Managed identity for Application Gateway Key Vault access'
        roleAssignments: []
      }
    ]
    enableDiagnostics: true
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
    enableTelemetry: false // Avoid duplicate telemetry
    tags: tags
    location: location
  }
  dependsOn: [
    managedIdentities
    logAnalyticsWorkspace
  ]
}

// Deploy Application Insights
module applicationInsights 'modules/monitoring/application-insights.bicep' = {
  name: 'application-insights-deployment'
  params: {
    applicationInsightsName: namingConventions.outputs.namingConvention.applicationInsights
    applicationType: 'web'
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
    enablePublicNetworkAccessForIngestion: !environmentConfig.enablePrivateEndpoints
    enablePublicNetworkAccessForQuery: !environmentConfig.enablePrivateEndpoints
    retentionInDays: environmentConfig.logRetentionDays
    dailyDataCapInGB: environmentConfig.skuTier == 'Basic' ? 1 : (environmentConfig.skuTier == 'Standard' ? 5 : 20)
    enableDailyDataCapReset: true
    samplingPercentage: environment == 'dev' ? 50 : 100
    enableRequestSource: true
    availabilityTestUrls: [
      'https://${applicationGateway.outputs.publicIpAddress}/health'
    ]
    availabilityTestLocations: [
      'us-east-1'
      'us-west-1'
      'europe-west-1'
    ]
    enableCustomMetrics: true
    enableLiveMetrics: true
    enableProfiler: environment != 'dev'
    enableSnapshotDebugger: environment == 'prod'
    tags: tags
    location: location
  }
  dependsOn: [
    logAnalyticsWorkspace
    applicationGateway
  ]
}

// Deploy Monitoring Alerts
module monitoringAlerts 'modules/monitoring/alerts.bicep' = {
  name: 'monitoring-alerts-deployment'
  params: {
    alertNamePrefix: '${resourcePrefix}-${workloadName}-${environment}'
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
    applicationInsightsId: applicationInsights.outputs.applicationInsightsId
    alertEmailAddresses: [] // Should be provided via parameters
    alertSmsNumbers: [] // Should be provided via parameters
    alertWebhookUrls: [] // Should be provided via parameters
    enableSecurityAlerts: true
    enablePerformanceAlerts: true
    enableAvailabilityAlerts: true
    monitoredResourceIds: [
      webTierVmScaleSet.outputs.vmScaleSetId
      businessTierVmScaleSet.outputs.vmScaleSetId
      applicationGateway.outputs.applicationGatewayId
      sqlServer.outputs.sqlServerId
      storageAccount.outputs.storageAccountId
    ]
    tags: tags
    location: location
  }
  dependsOn: [
    logAnalyticsWorkspace
    applicationInsights
    webTierVmScaleSet
    businessTierVmScaleSet
    applicationGateway
    sqlServer
    storageAccount
  ]
}

// Deploy Diagnostic Settings for Key Resources
module keyVaultDiagnostics 'modules/monitoring/diagnostic-settings.bicep' = {
  name: 'key-vault-diagnostics-deployment'
  params: {
    diagnosticSettingName: '${keyVault.outputs.keyVaultName}-diagnostics'
    targetResourceId: keyVault.outputs.keyVaultId
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
    storageAccountId: storageAccount.outputs.storageAccountId
    enableAllLogs: true
    enableAllMetrics: true
    logRetentionDays: environmentConfig.logRetentionDays
    metricRetentionDays: environmentConfig.logRetentionDays
    tags: tags
  }
  dependsOn: [
    keyVault
    logAnalyticsWorkspace
    storageAccount
  ]
}

module applicationGatewayDiagnostics 'modules/monitoring/diagnostic-settings.bicep' = {
  name: 'application-gateway-diagnostics-deployment'
  params: {
    diagnosticSettingName: '${applicationGateway.outputs.applicationGatewayName}-diagnostics'
    targetResourceId: applicationGateway.outputs.applicationGatewayId
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
    storageAccountId: storageAccount.outputs.storageAccountId
    enableAllLogs: true
    enableAllMetrics: true
    logRetentionDays: environmentConfig.logRetentionDays
    metricRetentionDays: environmentConfig.logRetentionDays
    tags: tags
  }
  dependsOn: [
    applicationGateway
    logAnalyticsWorkspace
    storageAccount
  ]
}

module loadBalancerDiagnostics 'modules/monitoring/diagnostic-settings.bicep' = [for (lbName, i) in ['business', 'data']: {
  name: '${lbName}-tier-load-balancer-diagnostics-deployment'
  params: {
    diagnosticSettingName: '${lbName}-tier-load-balancer-diagnostics'
    targetResourceId: lbName == 'business' ? businessTierLoadBalancer.outputs.loadBalancerId : dataTierLoadBalancer.outputs.loadBalancerId
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
    storageAccountId: storageAccount.outputs.storageAccountId
    enableAllLogs: true
    enableAllMetrics: true
    logRetentionDays: environmentConfig.logRetentionDays
    metricRetentionDays: environmentConfig.logRetentionDays
    tags: tags
  }
  dependsOn: [
    businessTierLoadBalancer
    dataTierLoadBalancer
    logAnalyticsWorkspace
    storageAccount
  ]
}]

module networkSecurityGroupDiagnostics 'modules/monitoring/diagnostic-settings.bicep' = [for (nsgName, i) in ['web', 'business', 'data', 'management']: {
  name: '${nsgName}-tier-nsg-diagnostics-deployment'
  params: {
    diagnosticSettingName: '${nsgName}-tier-nsg-diagnostics'
    targetResourceId: networkSecurityGroups.outputs.nsgIds['${nsgName}Tier']
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
    storageAccountId: storageAccount.outputs.storageAccountId
    enableAllLogs: true
    enableAllMetrics: true
    logRetentionDays: environmentConfig.logRetentionDays
    metricRetentionDays: environmentConfig.logRetentionDays
    tags: tags
  }
  dependsOn: [
    networkSecurityGroups
    logAnalyticsWorkspace
    storageAccount
  ]
}]

// ========================================
// DATA LAYER MODULES
// ========================================

// Deploy SQL Server and Database
module sqlServer 'modules/data/sql-server.bicep' = {
  name: 'sql-server-deployment'
  params: {
    sqlServerName: namingConventions.outputs.namingConvention.sqlServer
    sqlDatabaseName: replace(namingConventions.outputs.namingConvention.sqlDatabase, '{dbName}', workloadName)
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'P@ssw0rd123!' // This should come from Key Vault in production
    databaseSku: {
      name: environmentConfig.sqlDatabaseSku
      tier: environmentConfig.sqlDatabaseSku
      capacity: environmentConfig.skuTier == 'Basic' ? 5 : (environmentConfig.skuTier == 'Standard' ? 20 : 100)
    }
    maxSizeBytes: environmentConfig.skuTier == 'Basic' ? 2147483648 : (environmentConfig.skuTier == 'Standard' ? 268435456000 : 1099511627776) // 2GB, 250GB, 1TB
    enableAzureAdAuthentication: true
    azureAdAdministratorObjectId: managedIdentities.outputs.managedIdentityLookup.sqlAccess.principalId
    azureAdAdministratorLogin: 'SQL Administrators'
    azureAdAdministratorType: 'Group'
    enableTransparentDataEncryption: true
    enableAdvancedDataSecurity: environment != 'dev'
    enableVulnerabilityAssessment: environment != 'dev'
    vulnerabilityAssessmentStorageEndpoint: environment != 'dev' ? storageAccount.outputs.storageAccountEndpoints.blob : ''
    vulnerabilityAssessmentStorageAccessKey: environment != 'dev' ? storageAccount.outputs.storageAccountKey : ''
    enablePublicNetworkAccess: !environmentConfig.enablePrivateEndpoints
    allowedSubnetIds: environmentConfig.enablePrivateEndpoints ? [] : [
      virtualNetwork.outputs.subnetIds.dataTier
      virtualNetwork.outputs.subnetIds.businessTier
      virtualNetwork.outputs.subnetIds.management
    ]
    allowedIpAddresses: []
    minimalTlsVersion: '1.2'
    backupRetentionDays: environment == 'prod' ? 35 : 7
    enableGeoRedundantBackup: environment == 'prod'
    enableLongTermRetention: environment == 'prod'
    longTermRetentionBackup: environment == 'prod' ? {
      weeklyRetention: 'P12W'
      monthlyRetention: 'P12M'
      yearlyRetention: 'P7Y'
      weekOfYear: 1
    } : {
      weeklyRetention: 'PT0S'
      monthlyRetention: 'PT0S'
      yearlyRetention: 'PT0S'
      weekOfYear: 1
    }
    enableDiagnosticSettings: true
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
    diagnosticStorageAccountId: storageAccount.outputs.storageAccountId
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
    keyVault
    logAnalyticsWorkspace
    managedIdentities
  ]
}

// Deploy Storage Account
module storageAccount 'modules/data/storage-account.bicep' = {
  name: 'storage-account-deployment'
  params: {
    storageAccountName: namingConventions.outputs.specializedNames.storageAccount
    storageAccountSku: environmentConfig.storageAccountSku
    storageAccountKind: 'StorageV2'
    accessTier: 'Hot'
    enableHierarchicalNamespace: false
    enableLargeFileShares: false
    enableSftp: false
    enablePublicNetworkAccess: !environmentConfig.enablePrivateEndpoints
    allowedSubnetIds: environmentConfig.enablePrivateEndpoints ? [] : [
      virtualNetwork.outputs.subnetIds.dataTier
      virtualNetwork.outputs.subnetIds.businessTier
      virtualNetwork.outputs.subnetIds.webTier
      virtualNetwork.outputs.subnetIds.management
    ]
    allowedIpAddresses: []
    defaultNetworkAccessRule: environmentConfig.enablePrivateEndpoints ? 'Deny' : 'Allow'
    networkRulesBypass: 'AzureServices'
    minimumTlsVersion: 'TLS1_2'
    enableHttpsTrafficOnly: true
    enableBlobPublicAccess: false
    enableSharedKeyAccess: true
    enableInfrastructureEncryption: environment != 'dev'
    customerManagedKey: {
      enabled: environment == 'prod'
      keyVaultId: environment == 'prod' ? keyVault.outputs.keyVaultId : ''
      keyName: environment == 'prod' ? 'storage-encryption-key' : ''
      keyVersion: ''
      userAssignedIdentityId: environment == 'prod' ? managedIdentities.outputs.managedIdentityLookup.storageAccess.id : ''
    }
    enableBlobVersioning: environment != 'dev'
    enableBlobChangeFeed: environment != 'dev'
    enableBlobPointInTimeRestore: false
    pointInTimeRestoreRetentionDays: 7
    enableBlobSoftDelete: true
    blobSoftDeleteRetentionDays: environment == 'prod' ? 30 : 7
    enableContainerSoftDelete: true
    containerSoftDeleteRetentionDays: environment == 'prod' ? 30 : 7
    enableLifecycleManagement: true
    lifecycleRules: [
      {
        name: 'default-lifecycle-rule'
        enabled: true
        type: 'Lifecycle'
        definition: {
          filters: {
            blobTypes: ['blockBlob']
            prefixMatch: []
          }
          actions: {
            baseBlob: {
              tierToCool: {
                daysAfterModificationGreaterThan: environment == 'prod' ? 30 : 90
              }
              tierToArchive: {
                daysAfterModificationGreaterThan: environment == 'prod' ? 90 : 180
              }
              delete: {
                daysAfterModificationGreaterThan: environment == 'prod' ? 2555 : 365 // 7 years for prod, 1 year for others
              }
            }
            snapshot: {
              delete: {
                daysAfterCreationGreaterThan: environment == 'prod' ? 90 : 30
              }
            }
            version: {
              delete: {
                daysAfterCreationGreaterThan: environment == 'prod' ? 90 : 30
              }
            }
          }
        }
      }
    ]
    enableDiagnosticSettings: true
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
    diagnosticStorageAccountId: '' // Self-reference not allowed, will use separate storage for diagnostics
    blobContainers: [
      {
        name: 'application-data'
        publicAccess: 'None'
        metadata: {
          purpose: 'Application data storage'
          tier: 'data'
        }
      }
      {
        name: 'application-logs'
        publicAccess: 'None'
        metadata: {
          purpose: 'Application log storage'
          tier: 'logging'
        }
      }
      {
        name: 'database-backups'
        publicAccess: 'None'
        metadata: {
          purpose: 'Database backup storage'
          tier: 'backup'
        }
      }
      {
        name: 'vulnerability-assessment'
        publicAccess: 'None'
        metadata: {
          purpose: 'SQL vulnerability assessment reports'
          tier: 'security'
        }
      }
    ]
    fileShares: [
      {
        name: 'shared-files'
        shareQuota: environment == 'prod' ? 1024 : 100
        enabledProtocols: 'SMB'
        accessTier: 'TransactionOptimized'
      }
    ]
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
    logAnalyticsWorkspace
    managedIdentities
    keyVault
  ]
}

// Deploy Backup and Disaster Recovery (temporarily disabled due to errors)
// module backupRecovery 'modules/data/backup-recovery.bicep' = {
//   name: 'backup-recovery-deployment'
//   params: {
//     resourcePrefix: resourcePrefix
//     environment: environment
//     location: location
//     workloadName: workloadName
//     tags: tags
//     recoveryVaultConfig: {
//       skuName: 'Standard'
//       enableCrossRegionRestore: environment == 'prod'
//       enableSoftDelete: true
//       softDeleteRetentionDays: environment == 'prod' ? 14 : 7
//       enableSecuritySettings: true
//     }
//     sqlBackupConfig: {
//       shortTermRetentionDays: environment == 'prod' ? 35 : 7
//       enableLongTermRetention: environment == 'prod'
//       weeklyRetention: 'P12W'
//       monthlyRetention: 'P12M'
//       yearlyRetention: 'P7Y'
//       weekOfYear: 1
//       enableGeoRedundantBackup: environment == 'prod'
//       enableAutomatedBackupTesting: true
//     }
//     storageBackupConfig: {
//       enablePointInTimeRestore: environment == 'prod'
//       pointInTimeRestoreDays: environment == 'prod' ? 30 : 7
//       enableBlobVersioning: true
//       enableBlobSoftDelete: true
//       blobSoftDeleteRetentionDays: environment == 'prod' ? 30 : 7
//       enableContainerSoftDelete: true
//       containerSoftDeleteRetentionDays: environment == 'prod' ? 30 : 7
//       enableCrossRegionReplication: environment == 'prod'
//     }
//     disasterRecoveryConfig: {
//       enableCrossRegionReplication: environment == 'prod'
//       secondaryRegion: environment == 'prod' ? 'West US 2' : location
//       replicationFrequency: 'Daily'
//       retentionRange: environment == 'prod' ? 'P30D' : 'P7D'
//       enableAutomatedFailover: false
//       enableBackupTesting: true
//       testingSchedule: 'Weekly'
//     }
//     logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
//   }
//   dependsOn: [
//     sqlServer
//     storageAccount
//     logAnalyticsWorkspace
//   ]
// }

// Deploy Private Endpoints (if enabled)
module privateEndpoints 'modules/data/private-endpoints.bicep' = if (environmentConfig.enablePrivateEndpoints) {
  name: 'private-endpoints-deployment'
  params: {
    privateEndpointNamePrefix: replace(namingConventions.outputs.namingConvention.privateEndpoint, '{serviceName}', '')
    subnetId: virtualNetwork.outputs.subnetIds.dataTier
    virtualNetworkId: virtualNetwork.outputs.virtualNetworkId
    privateEndpointConfigs: [
      {
        name: 'sql-server'
        privateLinkServiceId: sqlServer.outputs.sqlServerId
        groupId: 'sqlServer'
      }
      {
        name: 'storage-blob'
        privateLinkServiceId: storageAccount.outputs.storageAccountId
        groupId: 'storageBlob'
      }
      {
        name: 'storage-file'
        privateLinkServiceId: storageAccount.outputs.storageAccountId
        groupId: 'storageFile'
      }
      {
        name: 'storage-queue'
        privateLinkServiceId: storageAccount.outputs.storageAccountId
        groupId: 'storageQueue'
      }
      {
        name: 'storage-table'
        privateLinkServiceId: storageAccount.outputs.storageAccountId
        groupId: 'storageTable'
      }
      {
        name: 'key-vault'
        privateLinkServiceId: keyVault.outputs.keyVaultId
        groupId: 'keyVault'
      }
    ]
    enablePrivateDnsZones: true
    existingPrivateDnsZoneIds: {}
    customDnsServers: []
    tags: tags
    location: location
  }
  dependsOn: [
    virtualNetwork
    sqlServer
    storageAccount
    keyVault
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
  // azurePolicy: {
  //   policyDefinitionIds: azurePolicy.outputs.policyDefinitionIds
  //   policySetDefinitionId: azurePolicy.outputs.policySetDefinitionId
  //   policyAssignmentIds: azurePolicy.outputs.policyAssignmentIds
  //   complianceReportingEnabled: azurePolicy.outputs.complianceReportingEnabled
  // }
  // securityBaseline: {
  //   securityBaselineConfig: securityBaseline.outputs.securityBaselineConfig
  //   auditLoggingEnabled: securityBaseline.outputs.auditLoggingEnabled
  //   complianceStatus: securityBaseline.outputs.complianceStatus
  // }
  managedIdentities: {
    ids: managedIdentities.outputs.managedIdentityIds
    names: managedIdentities.outputs.managedIdentityNames
    principalIds: managedIdentities.outputs.managedIdentityPrincipalIds
    clientIds: managedIdentities.outputs.managedIdentityClientIds
    configs: managedIdentities.outputs.managedIdentityConfigs
    lookup: managedIdentities.outputs.managedIdentityLookup
    roleDefinitions: managedIdentities.outputs.roleDefinitions
  }
}

// Compute outputs
output compute object = {
  publicIpAddress: {
    applicationGateway: {
      id: applicationGatewayPublicIp.outputs.publicIpAddressId
      name: applicationGatewayPublicIp.outputs.publicIpAddressName
      ipAddress: applicationGatewayPublicIp.outputs.ipAddress
      fqdn: applicationGatewayPublicIp.outputs.fqdn
      config: applicationGatewayPublicIp.outputs.publicIpConfig
    }
  }
  applicationGateway: {
    id: applicationGateway.outputs.applicationGatewayId
    name: applicationGateway.outputs.applicationGatewayName
    publicIpAddress: applicationGateway.outputs.publicIpAddress
    backendAddressPoolIds: applicationGateway.outputs.backendAddressPoolIds
    frontendIpConfigurationId: applicationGateway.outputs.frontendIpConfigurationId
    wafPolicyId: applicationGateway.outputs.wafPolicyId
    config: applicationGateway.outputs.applicationGatewayConfig
  }
  loadBalancers: {
    businessTier: {
      id: businessTierLoadBalancer.outputs.loadBalancerId
      name: businessTierLoadBalancer.outputs.loadBalancerName
      privateIpAddress: businessTierLoadBalancer.outputs.privateIpAddress
      frontendIpConfigurationId: businessTierLoadBalancer.outputs.frontendIpConfigurationId
      backendAddressPoolIds: businessTierLoadBalancer.outputs.backendAddressPoolIds
      healthProbeIds: businessTierLoadBalancer.outputs.healthProbeIds
      config: businessTierLoadBalancer.outputs.loadBalancerConfig
    }
    dataTier: {
      id: dataTierLoadBalancer.outputs.loadBalancerId
      name: dataTierLoadBalancer.outputs.loadBalancerName
      privateIpAddress: dataTierLoadBalancer.outputs.privateIpAddress
      frontendIpConfigurationId: dataTierLoadBalancer.outputs.frontendIpConfigurationId
      backendAddressPoolIds: dataTierLoadBalancer.outputs.backendAddressPoolIds
      healthProbeIds: dataTierLoadBalancer.outputs.healthProbeIds
      config: dataTierLoadBalancer.outputs.loadBalancerConfig
    }
  }
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

// Data layer outputs
output data object = {
  sqlServer: {
    id: sqlServer.outputs.sqlServerId
    name: sqlServer.outputs.sqlServerName
    fqdn: sqlServer.outputs.sqlServerFqdn
    connectionStringTemplate: sqlServer.outputs.connectionStringTemplate
    config: sqlServer.outputs.sqlServerConfig
  }
  sqlDatabase: {
    id: sqlServer.outputs.sqlDatabaseId
    name: sqlServer.outputs.sqlDatabaseName
    config: sqlServer.outputs.sqlDatabaseConfig
  }
  storageAccount: {
    id: storageAccount.outputs.storageAccountId
    name: storageAccount.outputs.storageAccountName
    endpoints: storageAccount.outputs.storageAccountEndpoints
    connectionString: storageAccount.outputs.storageAccountConnectionString
    blobContainers: storageAccount.outputs.blobContainerNames
    fileShares: storageAccount.outputs.fileShareNames
    config: storageAccount.outputs.storageAccountConfig
  }
  privateEndpoints: environmentConfig.enablePrivateEndpoints ? {
    endpoints: privateEndpoints.outputs.privateEndpointIds
    dnsZones: privateEndpoints.outputs.privateDnsZoneIds
    configs: privateEndpoints.outputs.privateEndpointConfigs
    dnsZoneNames: privateEndpoints.outputs.privateDnsZoneNames
  } : {
    endpoints: []
    dnsZones: {}
    configs: []
    dnsZoneNames: {}
  }
  // backupRecovery: {
  //   recoveryServicesVaultId: backupRecovery.outputs.recoveryServicesVaultId
  //   recoveryServicesVaultName: backupRecovery.outputs.recoveryServicesVaultName
  //   backupPolicyIds: backupRecovery.outputs.backupPolicyIds
  //   backupConfiguration: backupRecovery.outputs.backupConfiguration
  //   crossRegionReplicationEnabled: backupRecovery.outputs.crossRegionReplicationEnabled
  //   backupTestingEnabled: backupRecovery.outputs.backupTestingEnabled
  //   recoveryConfiguration: backupRecovery.outputs.recoveryConfiguration
  // }
}

// Monitoring outputs
output monitoring object = {
  logAnalyticsWorkspace: {
    id: logAnalyticsWorkspace.outputs.workspaceId
    name: logAnalyticsWorkspace.outputs.workspaceName
    customerId: logAnalyticsWorkspace.outputs.customerId
    dataCollectionRuleId: logAnalyticsWorkspace.outputs.dataCollectionRuleId
    config: logAnalyticsWorkspace.outputs.workspaceConfig
  }
  applicationInsights: {
    id: applicationInsights.outputs.applicationInsightsId
    name: applicationInsights.outputs.applicationInsightsName
    appId: applicationInsights.outputs.appId
    availabilityTestIds: applicationInsights.outputs.availabilityTestIds
    config: applicationInsights.outputs.applicationInsightsConfig
  }
  alerts: {
    actionGroupId: monitoringAlerts.outputs.actionGroupId
    criticalActionGroupId: monitoringAlerts.outputs.criticalActionGroupId
    alertRuleIds: monitoringAlerts.outputs.alertRuleIds
    config: monitoringAlerts.outputs.alertsConfig
  }
}