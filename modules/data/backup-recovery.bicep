// Backup and disaster recovery module
// This module creates backup policies for databases and storage,
// configures cross-region replication and recovery procedures

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
param tags object = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
  CostCenter: 'IT'
}

@description('Recovery Services Vault configuration')
param recoveryVaultConfig object = {
  skuName: 'Standard'
  enableCrossRegionRestore: environment == 'prod'
  enableSoftDelete: true
  softDeleteRetentionDays: environment == 'prod' ? 14 : 7
  enableSecuritySettings: true
}

@description('SQL Database backup configuration')
param sqlBackupConfig object = {
  shortTermRetentionDays: environment == 'prod' ? 35 : 7
  enableLongTermRetention: environment == 'prod'
  weeklyRetention: 'P12W'
  monthlyRetention: 'P12M'
  yearlyRetention: 'P7Y'
  weekOfYear: 1
  enableGeoRedundantBackup: environment == 'prod'
  enableAutomatedBackupTesting: true
}

@description('Storage Account backup configuration')
param storageBackupConfig object = {
  enablePointInTimeRestore: environment == 'prod'
  pointInTimeRestoreDays: environment == 'prod' ? 30 : 7
  enableBlobVersioning: true
  enableBlobSoftDelete: true
  blobSoftDeleteRetentionDays: environment == 'prod' ? 30 : 7
  enableContainerSoftDelete: true
  containerSoftDeleteRetentionDays: environment == 'prod' ? 30 : 7
  enableCrossRegionReplication: environment == 'prod'
}

@description('Disaster recovery configuration')
param disasterRecoveryConfig object = {
  enableCrossRegionReplication: environment == 'prod'
  secondaryRegion: environment == 'prod' ? 'West US 2' : location
  replicationFrequency: 'Daily'
  retentionRange: environment == 'prod' ? 'P30D' : 'P7D'
  enableAutomatedFailover: false
  enableBackupTesting: true
  testingSchedule: 'Weekly'
}

@description('Log Analytics workspace ID for monitoring')
param logAnalyticsWorkspaceId string = ''

// Variables for naming convention
var namingConvention = {
  recoveryVault: '${resourcePrefix}-${workloadName}-${environment}-rsv'
  backupPolicy: '${resourcePrefix}-${workloadName}-${environment}-backup-policy'
  diagnosticSetting: '${resourcePrefix}-${workloadName}-${environment}-diag'
}

// Recovery Services Vault
resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: namingConvention.recoveryVault
  location: location
  tags: tags
  sku: {
    name: recoveryVaultConfig.skuName
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    restoreSettings: {
      crossRegionRestore: recoveryVaultConfig.enableCrossRegionRestore ? 'Enabled' : 'Disabled'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Recovery Services Vault backup configuration
resource vaultBackupConfig 'Microsoft.RecoveryServices/vaults/backupconfig@2023-06-01' = {
  parent: recoveryServicesVault
  name: 'vaultconfig'
  properties: {
    enhancedSecurityState: recoveryVaultConfig.enableSecuritySettings ? 'Enabled' : 'Disabled'
    softDeleteFeatureState: recoveryVaultConfig.enableSoftDelete ? 'Enabled' : 'Disabled'
    softDeleteRetentionPeriodInDays: recoveryVaultConfig.softDeleteRetentionDays
    storageModelType: 'GeoRedundant'
    storageType: 'GeoRedundant'
    storageTypeState: 'Locked'
  }
}

// SQL Database backup policy
resource sqlBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-06-01' = {
  parent: recoveryServicesVault
  name: '${namingConvention.backupPolicy}-sql'
  properties: {
    backupManagementType: 'AzureSql'
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2023-01-01T02:00:00Z'
        ]
        retentionDuration: {
          count: sqlBackupConfig.shortTermRetentionDays
          durationType: 'Days'
        }
      }
      weeklySchedule: sqlBackupConfig.enableLongTermRetention ? {
        daysOfTheWeek: [
          'Sunday'
        ]
        retentionTimes: [
          '2023-01-01T02:00:00Z'
        ]
        retentionDuration: {
          count: int(replace(replace(sqlBackupConfig.weeklyRetention, 'P', ''), 'W', ''))
          durationType: 'Weeks'
        }
      } : null
      monthlySchedule: sqlBackupConfig.enableLongTermRetention ? {
        retentionScheduleFormatType: 'Weekly'
        retentionScheduleWeekly: {
          daysOfTheWeek: [
            'Sunday'
          ]
          weeksOfTheMonth: [
            'First'
          ]
        }
        retentionTimes: [
          '2023-01-01T02:00:00Z'
        ]
        retentionDuration: {
          count: int(replace(replace(sqlBackupConfig.monthlyRetention, 'P', ''), 'M', ''))
          durationType: 'Months'
        }
      } : null
      yearlySchedule: sqlBackupConfig.enableLongTermRetention ? {
        retentionScheduleFormatType: 'Weekly'
        monthsOfYear: [
          'January'
        ]
        retentionScheduleWeekly: {
          daysOfTheWeek: [
            'Sunday'
          ]
          weeksOfTheMonth: [
            'First'
          ]
        }
        retentionTimes: [
          '2023-01-01T02:00:00Z'
        ]
        retentionDuration: {
          count: int(replace(replace(sqlBackupConfig.yearlyRetention, 'P', ''), 'Y', ''))
          durationType: 'Years'
        }
      } : null
    }
  }
}

// Storage Account backup policy
resource storageBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-06-01' = {
  parent: recoveryServicesVault
  name: '${namingConvention.backupPolicy}-storage'
  properties: {
    backupManagementType: 'AzureStorage'
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2023-01-01T02:00:00Z'
        ]
        retentionDuration: {
          count: storageBackupConfig.pointInTimeRestoreDays
          durationType: 'Days'
        }
      }
    }
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '2023-01-01T02:00:00Z'
      ]
    }
  }
}

// Diagnostic settings for Recovery Services Vault
resource vaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  scope: recoveryServicesVault
  name: namingConvention.diagnosticSetting
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'CoreAzureBackup'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'AddonAzureBackupJobs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'AddonAzureBackupAlerts'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'AddonAzureBackupPolicy'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'AddonAzureBackupStorage'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'AddonAzureBackupProtectedInstance'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
    metrics: [
      {
        category: 'Health'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
  }
}

// Backup testing automation (Logic App for automated backup testing)
resource backupTestingLogicApp 'Microsoft.Logic/workflows@2019-05-01' = if (disasterRecoveryConfig.enableBackupTesting) {
  name: '${namingConvention.recoveryVault}-backup-testing'
  location: location
  tags: tags
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        recurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Week'
            interval: 1
            schedule: {
              hours: [
                2
              ]
              minutes: [
                0
              ]
              weekDays: [
                'Sunday'
              ]
            }
          }
        }
      }
      actions: {
        'HTTP-Backup-Test': {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://management.azure.com/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.RecoveryServices/vaults/${recoveryServicesVault.name}/backupJobs'
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              properties: {
                objectType: 'BackupTestJob'
                backupManagementType: 'AzureSql'
              }
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Cross-region replication configuration function
func getCrossRegionConfig(primaryRegion string, secondaryRegion string) object => {
  primaryRegion: primaryRegion
  secondaryRegion: secondaryRegion
  replicationEnabled: disasterRecoveryConfig.enableCrossRegionReplication
  replicationFrequency: disasterRecoveryConfig.replicationFrequency
  retentionRange: disasterRecoveryConfig.retentionRange
  automatedFailover: disasterRecoveryConfig.enableAutomatedFailover
}

// Outputs
output recoveryServicesVaultId string = recoveryServicesVault.id
output recoveryServicesVaultName string = recoveryServicesVault.name

output backupPolicyIds object = {
  sqlBackupPolicy: sqlBackupPolicy.id
  storageBackupPolicy: storageBackupPolicy.id
}

output backupConfiguration object = {
  sqlBackup: sqlBackupConfig
  storageBackup: storageBackupConfig
  disasterRecovery: disasterRecoveryConfig
}

output crossRegionReplicationEnabled bool = disasterRecoveryConfig.enableCrossRegionReplication

output backupTestingEnabled bool = disasterRecoveryConfig.enableBackupTesting

output backupTestingLogicAppId string = disasterRecoveryConfig.enableBackupTesting ? backupTestingLogicApp.id : ''

// Recovery configuration for use by other modules
output recoveryConfiguration object = {
  vaultId: recoveryServicesVault.id
  sqlPolicyId: sqlBackupPolicy.id
  storagePolicyId: storageBackupPolicy.id
  crossRegionEnabled: disasterRecoveryConfig.enableCrossRegionReplication
  secondaryRegion: disasterRecoveryConfig.secondaryRegion
  testingEnabled: disasterRecoveryConfig.enableBackupTesting
}