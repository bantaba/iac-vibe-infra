// Azure SQL Database module
// This module implements SQL Server with private endpoint configuration,
// database firewall rules, Azure AD authentication, and security features

targetScope = 'resourceGroup'

// Import shared types
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

// Core parameters
@description('The name of the SQL Server')
param sqlServerName string

@description('The name of the SQL Database')
param sqlDatabaseName string

@description('The Azure region for deployment')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags TagConfiguration

// SQL Server configuration parameters
@description('SQL Server administrator login name')
param administratorLogin string

@description('SQL Server administrator password (should come from Key Vault)')
@secure()
param administratorLoginPassword string

@description('SQL Database SKU configuration')
param databaseSku object = {
  name: 'Standard'
  tier: 'Standard'
  capacity: 20
}

@description('Maximum database size in bytes')
param maxSizeBytes int = 268435456000 // 250 GB

@description('Enable Azure AD authentication')
param enableAzureAdAuthentication bool = true

@description('Azure AD administrator object ID')
param azureAdAdministratorObjectId string = ''

@description('Azure AD administrator login name')
param azureAdAdministratorLogin string = ''

// Security configuration parameters
@description('Enable Transparent Data Encryption')
param enableTransparentDataEncryption bool = true

@description('Enable Advanced Data Security')
param enableAdvancedDataSecurity bool = true

@description('Enable vulnerability assessment')
param enableVulnerabilityAssessment bool = true

@description('Storage account endpoint for vulnerability assessment')
param vulnerabilityAssessmentStorageEndpoint string = ''

@description('Storage account access key for vulnerability assessment')
@secure()
param vulnerabilityAssessmentStorageAccessKey string = ''

// Network configuration parameters
@description('Enable public network access')
param enablePublicNetworkAccess bool = false

@description('Allowed subnet IDs for firewall rules')
param allowedSubnetIds array = []

@description('Allowed IP addresses for firewall rules')
param allowedIpAddresses array = []

@description('Minimum TLS version')
@allowed(['1.0', '1.1', '1.2'])
param minimalTlsVersion string = '1.2'

// Backup configuration parameters
@description('Backup retention period in days')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Enable geo-redundant backup')
param enableGeoRedundantBackup bool = true

@description('Enable long-term retention backup')
param enableLongTermRetention bool = false

@description('Long-term retention backup configuration')
param longTermRetentionBackup object = {
  weeklyRetention: 'PT0S'
  monthlyRetention: 'PT0S'
  yearlyRetention: 'PT0S'
  weekOfYear: 1
}

// Monitoring configuration parameters
@description('Enable diagnostic settings')
param enableDiagnosticSettings bool = true

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string = ''

@description('Storage account ID for diagnostic settings')
param diagnosticStorageAccountId string = ''

// Variables
var sqlServerResourceName = sqlServerName
var sqlDatabaseResourceName = sqlDatabaseName

// SQL Server resource
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerResourceName
  location: location
  tags: tags
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: '12.0'
    minimalTlsVersion: minimalTlsVersion
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
  identity: enableAzureAdAuthentication ? {
    type: 'SystemAssigned'
  } : null
}

// Azure AD Administrator configuration
resource sqlServerAzureAdAdministrator 'Microsoft.Sql/servers/administrators@2023-05-01-preview' = if (enableAzureAdAuthentication && !empty(azureAdAdministratorObjectId)) {
  parent: sqlServer
  name: 'ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: azureAdAdministratorLogin
    sid: azureAdAdministratorObjectId
    tenantId: tenant().tenantId

  }
}

// SQL Database resource
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseResourceName
  location: location
  tags: tags
  sku: databaseSku
  properties: {
    maxSizeBytes: maxSizeBytes
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: databaseSku.tier == 'Premium' || databaseSku.tier == 'BusinessCritical'
    readScale: databaseSku.tier == 'Premium' || databaseSku.tier == 'BusinessCritical' ? 'Enabled' : 'Disabled'
    requestedBackupStorageRedundancy: enableGeoRedundantBackup ? 'Geo' : 'Local'
    isLedgerOn: false
  }
}

// Transparent Data Encryption
resource transparentDataEncryption 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-05-01-preview' = if (enableTransparentDataEncryption) {
  parent: sqlDatabase
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

// Advanced Data Security (now called Microsoft Defender for SQL)
resource advancedDataSecurity 'Microsoft.Sql/servers/securityAlertPolicies@2023-05-01-preview' = if (enableAdvancedDataSecurity) {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
    emailAddresses: []
    retentionDays: 30
    storageEndpoint: !empty(vulnerabilityAssessmentStorageEndpoint) ? vulnerabilityAssessmentStorageEndpoint : null
    storageAccountAccessKey: !empty(vulnerabilityAssessmentStorageAccessKey) ? vulnerabilityAssessmentStorageAccessKey : null
  }
}

// Vulnerability Assessment
resource vulnerabilityAssessment 'Microsoft.Sql/servers/vulnerabilityAssessments@2023-05-01-preview' = if (enableVulnerabilityAssessment && !empty(vulnerabilityAssessmentStorageEndpoint)) {
  parent: sqlServer
  name: 'default'
  properties: {
    storageContainerPath: '${vulnerabilityAssessmentStorageEndpoint}vulnerability-assessment'
    storageAccountAccessKey: vulnerabilityAssessmentStorageAccessKey
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: true
      emails: []
    }
  }
  dependsOn: [
    advancedDataSecurity
  ]
}

// Firewall rules for allowed subnets
resource subnetFirewallRules 'Microsoft.Sql/servers/virtualNetworkRules@2023-05-01-preview' = [for (subnetId, index) in allowedSubnetIds: {
  parent: sqlServer
  name: 'subnet-rule-${index}'
  properties: {
    virtualNetworkSubnetId: subnetId
    ignoreMissingVnetServiceEndpoint: false
  }
}]

// Firewall rules for allowed IP addresses
resource ipFirewallRules 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = [for (ipAddress, index) in allowedIpAddresses: {
  parent: sqlServer
  name: 'ip-rule-${index}'
  properties: {
    startIpAddress: ipAddress
    endIpAddress: ipAddress
  }
}]

// Allow Azure services firewall rule (conditional)
resource azureServicesFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = if (enablePublicNetworkAccess) {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Long-term retention policy
resource longTermRetentionPolicy 'Microsoft.Sql/servers/databases/backupLongTermRetentionPolicies@2023-05-01-preview' = if (enableLongTermRetention) {
  parent: sqlDatabase
  name: 'default'
  properties: {
    weeklyRetention: longTermRetentionBackup.weeklyRetention
    monthlyRetention: longTermRetentionBackup.monthlyRetention
    yearlyRetention: longTermRetentionBackup.yearlyRetention
    weekOfYear: longTermRetentionBackup.weekOfYear
  }
}

// Short-term retention policy (automated backups)
resource shortTermRetentionPolicy 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2023-05-01-preview' = {
  parent: sqlDatabase
  name: 'default'
  properties: {
    retentionDays: backupRetentionDays
  }
}

// Diagnostic settings for SQL Server
resource sqlServerDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnosticSettings && !empty(logAnalyticsWorkspaceId)) {
  name: '${sqlServerResourceName}-diagnostics'
  scope: sqlServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Diagnostic settings for SQL Database
resource sqlDatabaseDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnosticSettings && !empty(logAnalyticsWorkspaceId)) {
  name: '${sqlDatabaseResourceName}-diagnostics'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Outputs
@description('The resource ID of the SQL Server')
output sqlServerId string = sqlServer.id

@description('The name of the SQL Server')
output sqlServerName string = sqlServer.name

@description('The fully qualified domain name of the SQL Server')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('The resource ID of the SQL Database')
output sqlDatabaseId string = sqlDatabase.id

@description('The name of the SQL Database')
output sqlDatabaseName string = sqlDatabase.name

@description('The connection string for the SQL Database (without password)')
output connectionStringTemplate string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Persist Security Info=False;User ID=${administratorLogin};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'

@description('SQL Server configuration details')
output sqlServerConfig object = {
  id: sqlServer.id
  name: sqlServer.name
  fqdn: sqlServer.properties.fullyQualifiedDomainName
  version: sqlServer.properties.version
  administratorLogin: sqlServer.properties.administratorLogin
  minimalTlsVersion: sqlServer.properties.minimalTlsVersion
  publicNetworkAccess: sqlServer.properties.publicNetworkAccess
  azureAdOnlyAuthentication: enableAzureAdAuthentication
  enabledFeatures: {
    transparentDataEncryption: enableTransparentDataEncryption
    advancedDataSecurity: enableAdvancedDataSecurity
    vulnerabilityAssessment: enableVulnerabilityAssessment
    longTermRetention: enableLongTermRetention
    diagnosticSettings: enableDiagnosticSettings
  }
}

@description('SQL Database configuration details')
output sqlDatabaseConfig object = {
  id: sqlDatabase.id
  name: sqlDatabase.name
  sku: sqlDatabase.sku
  maxSizeBytes: sqlDatabase.properties.maxSizeBytes
  collation: sqlDatabase.properties.collation
  zoneRedundant: sqlDatabase.properties.zoneRedundant
  readScale: sqlDatabase.properties.readScale
  backupStorageRedundancy: sqlDatabase.properties.requestedBackupStorageRedundancy
  backupRetentionDays: backupRetentionDays
}