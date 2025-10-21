// Azure Storage Account module
// This module implements storage accounts with private endpoints, network restrictions,
// encryption, access policies, and lifecycle management

targetScope = 'resourceGroup'

// Import shared types
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

// Core parameters
@description('The name of the storage account')
param storageAccountName string

@description('The Azure region for deployment')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags TagConfiguration

// Storage account configuration parameters
@description('Storage account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS', 'Standard_GZRS', 'Premium_LRS', 'Premium_ZRS'])
param storageAccountSku string = 'Standard_LRS'

@description('Storage account kind')
@allowed(['Storage', 'StorageV2', 'BlobStorage', 'FileStorage', 'BlockBlobStorage'])
param storageAccountKind string = 'StorageV2'

@description('Storage account access tier')
@allowed(['Hot', 'Cool'])
param accessTier string = 'Hot'

@description('Enable hierarchical namespace (Data Lake Gen2)')
param enableHierarchicalNamespace bool = false

@description('Enable large file shares')
param enableLargeFileShares bool = false

@description('Enable SFTP')
param enableSftp bool = false

// Security configuration parameters
@description('Enable public network access')
param enablePublicNetworkAccess bool = false

@description('Allowed subnet IDs for network rules')
param allowedSubnetIds array = []

@description('Allowed IP addresses for network rules')
param allowedIpAddresses array = []

@description('Default network access rule')
@allowed(['Allow', 'Deny'])
param defaultNetworkAccessRule string = 'Deny'

@description('Bypass network rules for Azure services')
@allowed(['None', 'AzureServices', 'Logging', 'Metrics'])
param networkRulesBypass string = 'AzureServices'

@description('Minimum TLS version')
@allowed(['TLS1_0', 'TLS1_1', 'TLS1_2'])
param minimumTlsVersion string = 'TLS1_2'

@description('Enable HTTPS traffic only')
param enableHttpsTrafficOnly bool = true

@description('Enable blob public access')
param enableBlobPublicAccess bool = false

@description('Enable shared key access')
param enableSharedKeyAccess bool = true

// Encryption configuration parameters
@description('Enable infrastructure encryption')
param enableInfrastructureEncryption bool = true

@description('Customer-managed key configuration')
param customerManagedKey object = {
  enabled: false
  keyVaultId: ''
  keyName: ''
  keyVersion: ''
  userAssignedIdentityId: ''
}

// Blob service configuration parameters
@description('Enable blob versioning')
param enableBlobVersioning bool = true

@description('Enable blob change feed')
param enableBlobChangeFeed bool = true

@description('Enable blob point-in-time restore')
param enableBlobPointInTimeRestore bool = false

@description('Point-in-time restore retention days')
@minValue(1)
@maxValue(365)
param pointInTimeRestoreRetentionDays int = 7

@description('Enable blob soft delete')
param enableBlobSoftDelete bool = true

@description('Blob soft delete retention days')
@minValue(1)
@maxValue(365)
param blobSoftDeleteRetentionDays int = 7

@description('Enable container soft delete')
param enableContainerSoftDelete bool = true

@description('Container soft delete retention days')
@minValue(1)
@maxValue(365)
param containerSoftDeleteRetentionDays int = 7

// Lifecycle management parameters
@description('Enable lifecycle management')
param enableLifecycleManagement bool = true

@description('Lifecycle management rules')
param lifecycleRules array = [
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
            daysAfterModificationGreaterThan: 30
          }
          tierToArchive: {
            daysAfterModificationGreaterThan: 90
          }
          delete: {
            daysAfterModificationGreaterThan: 365
          }
        }
        snapshot: {
          delete: {
            daysAfterCreationGreaterThan: 30
          }
        }
        version: {
          delete: {
            daysAfterCreationGreaterThan: 30
          }
        }
      }
    }
  }
]

// Monitoring configuration parameters
@description('Enable diagnostic settings')
param enableDiagnosticSettings bool = true

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string = ''

@description('Storage account ID for diagnostic settings')
param diagnosticStorageAccountId string = ''

// Container configuration parameters
@description('Blob containers to create')
param blobContainers array = [
  {
    name: 'data'
    publicAccess: 'None'
    metadata: {}
  }
  {
    name: 'logs'
    publicAccess: 'None'
    metadata: {}
  }
  {
    name: 'backups'
    publicAccess: 'None'
    metadata: {}
  }
]

// File share configuration parameters
@description('File shares to create')
param fileShares array = [
  {
    name: 'shared'
    shareQuota: 100
    enabledProtocols: 'SMB'
    accessTier: 'TransactionOptimized'
  }
]

// Variables
var storageAccountResourceName = storageAccountName

// Storage Account resource
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountResourceName
  location: location
  tags: tags
  sku: {
    name: storageAccountSku
  }
  kind: storageAccountKind
  identity: customerManagedKey.enabled ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${customerManagedKey.userAssignedIdentityId}': {}
    }
  } : {
    type: 'SystemAssigned'
  }
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: enableBlobPublicAccess
    allowSharedKeyAccess: enableSharedKeyAccess
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: true
    dnsEndpointType: 'Standard'
    isHnsEnabled: enableHierarchicalNamespace
    isLocalUserEnabled: enableSftp
    isNfsV3Enabled: false
    isSftpEnabled: enableSftp
    largeFileSharesState: enableLargeFileShares ? 'Enabled' : 'Disabled'
    minimumTlsVersion: minimumTlsVersion
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
    supportsHttpsTrafficOnly: enableHttpsTrafficOnly
    networkAcls: {
      bypass: networkRulesBypass
      defaultAction: defaultNetworkAccessRule
      ipRules: [for ipAddress in allowedIpAddresses: {
        value: ipAddress
        action: 'Allow'
      }]
      virtualNetworkRules: [for subnetId in allowedSubnetIds: {
        id: subnetId
        action: 'Allow'
        state: 'Succeeded'
      }]
    }
    encryption: {
      requireInfrastructureEncryption: enableInfrastructureEncryption
      services: {
        blob: {
          enabled: true
          keyType: customerManagedKey.enabled ? 'Account' : 'Service'
        }
        file: {
          enabled: true
          keyType: customerManagedKey.enabled ? 'Account' : 'Service'
        }
        table: {
          enabled: true
          keyType: 'Service'
        }
        queue: {
          enabled: true
          keyType: 'Service'
        }
      }
      keySource: customerManagedKey.enabled ? 'Microsoft.Keyvault' : 'Microsoft.Storage'
      keyvaultproperties: customerManagedKey.enabled ? {
        keyname: customerManagedKey.keyName
        keyversion: customerManagedKey.keyVersion
        keyvaulturi: 'https://${split(customerManagedKey.keyVaultId, '/')[8]}.${environment().suffixes.keyvaultDns}/'
      } : null
    }
  }
}

// Blob Service configuration
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    changeFeed: {
      enabled: enableBlobChangeFeed
      retentionInDays: enableBlobChangeFeed ? 7 : null
    }
    restorePolicy: enableBlobPointInTimeRestore ? {
      enabled: true
      days: pointInTimeRestoreRetentionDays
    } : {
      enabled: false
    }
    deleteRetentionPolicy: {
      enabled: enableBlobSoftDelete
      days: enableBlobSoftDelete ? blobSoftDeleteRetentionDays : null
    }
    containerDeleteRetentionPolicy: {
      enabled: enableContainerSoftDelete
      days: enableContainerSoftDelete ? containerSoftDeleteRetentionDays : null
    }
    isVersioningEnabled: enableBlobVersioning
  }
}

// Blob containers
resource blobContainersResource 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for container in blobContainers: {
  parent: blobService
  name: container.name
  properties: {
    publicAccess: container.publicAccess
    metadata: container.metadata
  }
}]

// File Service configuration
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = if (length(fileShares) > 0) {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// File shares
resource fileSharesResource 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = [for share in fileShares: if (length(fileShares) > 0) {
  parent: fileService
  name: share.name
  properties: {
    shareQuota: share.shareQuota
    enabledProtocols: share.enabledProtocols
    accessTier: share.accessTier
  }
}]

// Management Policy (Lifecycle Management)
resource managementPolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = if (enableLifecycleManagement) {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: lifecycleRules
    }
  }
}

// Diagnostic settings for Storage Account
resource storageAccountDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnosticSettings && !empty(logAnalyticsWorkspaceId)) {
  name: '${storageAccountResourceName}-diagnostics'
  scope: storageAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    metrics: [
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Capacity'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Diagnostic settings for Blob Service
resource blobServiceDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnosticSettings && !empty(logAnalyticsWorkspaceId)) {
  name: '${storageAccountResourceName}-blob-diagnostics'
  scope: blobService
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
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Capacity'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Diagnostic settings for File Service
resource fileServiceDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnosticSettings && !empty(logAnalyticsWorkspaceId) && length(fileShares) > 0) {
  name: '${storageAccountResourceName}-file-diagnostics'
  scope: fileService
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
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Capacity'
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
@description('The resource ID of the storage account')
output storageAccountId string = storageAccount.id

@description('The name of the storage account')
output storageAccountName string = storageAccount.name

@description('The primary endpoints of the storage account')
output storageAccountEndpoints object = storageAccount.properties.primaryEndpoints

@description('The primary access key of the storage account')
output storageAccountKey string = storageAccount.listKeys().keys[0].value

@description('The connection string for the storage account')
output storageAccountConnectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'

@description('The blob container names')
output blobContainerNames array = [for container in blobContainers: container.name]

@description('The file share names')
output fileShareNames array = [for share in fileShares: share.name]

@description('Storage account configuration details')
output storageAccountConfig object = {
  id: storageAccount.id
  name: storageAccount.name
  sku: storageAccount.sku
  kind: storageAccount.kind
  accessTier: storageAccount.properties.accessTier
  endpoints: storageAccount.properties.primaryEndpoints
  networkAccess: storageAccount.properties.publicNetworkAccess
  httpsOnly: storageAccount.properties.supportsHttpsTrafficOnly
  minimumTlsVersion: storageAccount.properties.minimumTlsVersion
  enabledFeatures: {
    hierarchicalNamespace: storageAccount.properties.isHnsEnabled
    blobPublicAccess: storageAccount.properties.allowBlobPublicAccess
    sharedKeyAccess: storageAccount.properties.allowSharedKeyAccess
    infrastructureEncryption: enableInfrastructureEncryption
    blobVersioning: enableBlobVersioning
    blobChangeFeed: enableBlobChangeFeed
    blobSoftDelete: enableBlobSoftDelete
    containerSoftDelete: enableContainerSoftDelete
    lifecycleManagement: enableLifecycleManagement
    diagnosticSettings: enableDiagnosticSettings
  }
  containers: blobContainers
  fileShares: fileShares
}