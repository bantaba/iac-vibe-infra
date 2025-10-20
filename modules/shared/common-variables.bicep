// Common variables and constants used across all modules
// This module provides shared configuration values and lookup tables

// Azure region mappings for resource deployment
var regionMappings = {
  'East US': 'eastus'
  'East US 2': 'eastus2'
  'West US': 'westus'
  'West US 2': 'westus2'
  'West US 3': 'westus3'
  'Central US': 'centralus'
  'North Central US': 'northcentralus'
  'South Central US': 'southcentralus'
  'West Central US': 'westcentralus'
  'Canada Central': 'canadacentral'
  'Canada East': 'canadaeast'
  'Brazil South': 'brazilsouth'
  'North Europe': 'northeurope'
  'West Europe': 'westeurope'
  'UK South': 'uksouth'
  'UK West': 'ukwest'
  'France Central': 'francecentral'
  'Germany West Central': 'germanywestcentral'
  'Switzerland North': 'switzerlandnorth'
  'Norway East': 'norwayeast'
  'Southeast Asia': 'southeastasia'
  'East Asia': 'eastasia'
  'Australia East': 'australiaeast'
  'Australia Southeast': 'australiasoutheast'
  'Japan East': 'japaneast'
  'Japan West': 'japanwest'
  'Korea Central': 'koreacentral'
  'India Central': 'centralindia'
  'India South': 'southindia'
  'UAE North': 'uaenorth'
  'South Africa North': 'southafricanorth'
}

// Common port definitions
var commonPorts = {
  http: 80
  https: 443
  ssh: 22
  rdp: 3389
  sql: 1433
  mysql: 3306
  postgresql: 5432
  redis: 6379
  mongodb: 27017
  smtp: 25
  smtps: 465
  pop3: 110
  pop3s: 995
  imap: 143
  imaps: 993
  ftp: 21
  ftps: 990
  sftp: 22
  dns: 53
  dhcp: 67
  ntp: 123
  snmp: 161
  ldap: 389
  ldaps: 636
  kerberos: 88
  winrm: 5985
  winrms: 5986
}

// Network Security Group rule priorities
var nsgRulePriorities = {
  // Inbound rules (100-999)
  allowApplicationGateway: 100
  allowLoadBalancer: 110
  allowVnetTraffic: 120
  allowManagementAccess: 130
  allowMonitoring: 140
  denyAllInbound: 4000
  
  // Outbound rules (1000-1999)
  allowInternetAccess: 1000
  allowVnetOutbound: 1010
  allowStorageAccess: 1020
  allowKeyVaultAccess: 1030
  allowSqlAccess: 1040
  denyAllOutbound: 4000
}

// Application Gateway configuration constants
var applicationGatewayDefaults = {
  requestTimeout: 20
  cookieBasedAffinity: 'Disabled'
  protocol: 'Https'
  port: 443
  healthProbe: {
    interval: 30
    timeout: 30
    unhealthyThreshold: 3
    path: '/health'
    statusCodes: ['200-399']
  }
  wafMode: 'Prevention'
  wafRuleSetType: 'OWASP'
  wafRuleSetVersion: '3.2'
}

// Load Balancer configuration constants
var loadBalancerDefaults = {
  idleTimeoutInMinutes: 4
  enableFloatingIp: false
  loadDistribution: 'Default'
  healthProbe: {
    intervalInSeconds: 15
    numberOfProbes: 2
    port: 80
    protocol: 'Http'
    requestPath: '/health'
  }
}

// Key Vault configuration constants
var keyVaultDefaults = {
  sku: 'standard'
  enableSoftDelete: true
  softDeleteRetentionInDays: 90
  enablePurgeProtection: true
  enableRbacAuthorization: true
  networkAcls: {
    bypass: 'AzureServices'
    defaultAction: 'Deny'
  }
}

// Storage Account configuration constants
var storageAccountDefaults = {
  kind: 'StorageV2'
  accessTier: 'Hot'
  supportsHttpsTrafficOnly: true
  minimumTlsVersion: 'TLS1_2'
  allowBlobPublicAccess: false
  allowSharedKeyAccess: false
  networkAcls: {
    bypass: 'AzureServices'
    defaultAction: 'Deny'
  }
}

// SQL Database configuration constants
var sqlDatabaseDefaults = {
  collation: 'SQL_Latin1_General_CP1_CI_AS'
  maxSizeBytes: 268435456000
  zoneRedundant: false
  readScale: 'Disabled'
  minCapacity: 1
  autoPauseDelay: 60
  enableAdvancedDataSecurity: true
  enableVulnerabilityAssessment: true
  enableAuditing: true
}

// Virtual Machine configuration constants
var virtualMachineDefaults = {
  osDisk: {
    storageAccountType: 'Premium_LRS'
    diskSizeGB: 128
    caching: 'ReadWrite'
  }
  networkInterface: {
    enableAcceleratedNetworking: true
    enableIpForwarding: false
  }
  bootDiagnostics: {
    enabled: true
  }
}

// Log Analytics workspace configuration constants
var logAnalyticsDefaults = {
  sku: 'PerGB2018'
  retentionInDays: 30
  dailyQuotaGb: 1
  enableLogAccessUsingOnlyResourcePermissions: true
}

// Monitoring and alerting constants
var monitoringDefaults = {
  metricAlerts: {
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    severity: 2
    autoMitigate: true
  }
  actionGroups: {
    emailReceiver: {
      useCommonAlertSchema: true
    }
    smsReceiver: {
      countryCode: '1'
    }
  }
}

// Private endpoint configuration constants
var privateEndpointDefaults = {
  privateDnsZoneGroups: {
    sql: 'privatelink.database.windows.net'
    storage: 'privatelink.blob.core.windows.net'
    keyVault: 'privatelink.vaultcore.azure.net'
    monitor: 'privatelink.monitor.azure.com'
    oms: 'privatelink.oms.opinsights.azure.com'
    ods: 'privatelink.ods.opinsights.azure.com'
    agentsvc: 'privatelink.agentsvc.azure-automation.net'
  }
}

// Output all constants and configurations
output regionMappings object = regionMappings
output commonPorts object = commonPorts
output nsgRulePriorities object = nsgRulePriorities
output applicationGatewayDefaults object = applicationGatewayDefaults
output loadBalancerDefaults object = loadBalancerDefaults
output keyVaultDefaults object = keyVaultDefaults
output storageAccountDefaults object = storageAccountDefaults
output sqlDatabaseDefaults object = sqlDatabaseDefaults
output virtualMachineDefaults object = virtualMachineDefaults
output logAnalyticsDefaults object = logAnalyticsDefaults
output monitoringDefaults object = monitoringDefaults
output privateEndpointDefaults object = privateEndpointDefaults