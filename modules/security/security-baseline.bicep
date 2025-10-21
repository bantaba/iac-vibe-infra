// Security baseline configuration module
// This module implements security baseline settings across all resources
// and configures audit logging for administrative operations

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

@description('Log Analytics workspace resource ID for audit logging')
param logAnalyticsWorkspaceId string

@description('Enable security baseline configuration')
param enableSecurityBaseline bool = true

@description('Enable audit logging for administrative operations')
param enableAuditLogging bool = true

@description('Security baseline configuration settings')
param securityBaselineConfig object = {
  requireHttpsOnly: true
  requireTlsVersion: '1.2'
  enableAdvancedThreatProtection: true
  requirePrivateEndpoints: environment == 'prod'
  enableNetworkSecurityGroups: true
  requireManagedIdentity: true
  enableDiagnosticSettings: true
  auditRetentionDays: environment == 'prod' ? 365 : 90
}

// Variables for naming convention
var namingConvention = {
  diagnosticSetting: '${resourcePrefix}-${workloadName}-${environment}-diag'
  securityContact: '${resourcePrefix}-${workloadName}-${environment}-security-contact'
}

// Security baseline diagnostic settings template
var diagnosticSettingsTemplate = {
  workspaceId: logAnalyticsWorkspaceId
  logs: [
    {
      categoryGroup: 'allLogs'
      enabled: true
      retentionPolicy: {
        enabled: true
        days: securityBaselineConfig.auditRetentionDays
      }
    }
    {
      categoryGroup: 'audit'
      enabled: true
      retentionPolicy: {
        enabled: true
        days: securityBaselineConfig.auditRetentionDays
      }
    }
  ]
  metrics: [
    {
      category: 'AllMetrics'
      enabled: true
      retentionPolicy: {
        enabled: true
        days: securityBaselineConfig.auditRetentionDays
      }
    }
  ]
}

// Security contact configuration for Azure Security Center
resource securityContact 'Microsoft.Security/securityContacts@2020-01-01-preview' = if (enableSecurityBaseline) {
  name: namingConvention.securityContact
  properties: {
    emails: 'security@${workloadName}.com'
    notificationsByRole: {
      state: 'On'
      roles: [
        'Owner'
        'Contributor'
      ]
    }
    alertNotifications: {
      state: 'On'
      minimalSeverity: 'Medium'
    }
  }
}

// Auto-provisioning configuration for Security Center
resource autoProvisioning 'Microsoft.Security/autoProvisioningSettings@2017-08-01-preview' = if (enableSecurityBaseline) {
  name: 'default'
  properties: {
    autoProvision: 'On'
  }
}

// Security Center workspace settings
resource workspaceSettings 'Microsoft.Security/workspaceSettings@2017-08-01-preview' = if (enableSecurityBaseline && !empty(logAnalyticsWorkspaceId)) {
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    scope: subscription().id
  }
}

// Activity log diagnostic settings for subscription-level audit logging
resource activityLogDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableAuditLogging && !empty(logAnalyticsWorkspaceId)) {
  scope: subscription()
  name: '${namingConvention.diagnosticSetting}-activity-log'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'Administrative'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: securityBaselineConfig.auditRetentionDays
        }
      }
      {
        category: 'Security'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: securityBaselineConfig.auditRetentionDays
        }
      }
      {
        category: 'ServiceHealth'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: securityBaselineConfig.auditRetentionDays
        }
      }
      {
        category: 'Alert'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: securityBaselineConfig.auditRetentionDays
        }
      }
      {
        category: 'Recommendation'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: securityBaselineConfig.auditRetentionDays
        }
      }
      {
        category: 'Policy'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: securityBaselineConfig.auditRetentionDays
        }
      }
      {
        category: 'Autoscale'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: securityBaselineConfig.auditRetentionDays
        }
      }
      {
        category: 'ResourceHealth'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: securityBaselineConfig.auditRetentionDays
        }
      }
    ]
  }
}

// Security baseline validation function
func validateSecurityBaseline(resourceType string, resourceConfig object) object => {
  httpsOnly: securityBaselineConfig.requireHttpsOnly ? (contains(resourceConfig, 'supportsHttpsTrafficOnly') ? resourceConfig.supportsHttpsTrafficOnly : true) : true
  tlsVersion: securityBaselineConfig.requireTlsVersion != '' ? (contains(resourceConfig, 'minimumTlsVersion') ? resourceConfig.minimumTlsVersion : securityBaselineConfig.requireTlsVersion) : '1.2'
  advancedThreatProtection: securityBaselineConfig.enableAdvancedThreatProtection
  privateEndpoints: securityBaselineConfig.requirePrivateEndpoints
  networkSecurityGroups: securityBaselineConfig.enableNetworkSecurityGroups
  managedIdentity: securityBaselineConfig.requireManagedIdentity
  diagnosticSettings: securityBaselineConfig.enableDiagnosticSettings
}

// Security configuration validation automation
resource securityValidationLogicApp 'Microsoft.Logic/workflows@2019-05-01' = if (enableSecurityBaseline) {
  name: '${namingConvention.diagnosticSetting}-security-validation'
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
            frequency: 'Hour'
            interval: 6
          }
        }
      }
      actions: {
        'Validate-Key-Vault-Security': {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: 'https://management.azure.com/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.KeyVault/vaults?api-version=2023-07-01'
            headers: {
              'Content-Type': 'application/json'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
        'Validate-Storage-Security': {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: 'https://management.azure.com/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Storage/storageAccounts?api-version=2023-01-01'
            headers: {
              'Content-Type': 'application/json'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
          runAfter: {
            'Validate-Key-Vault-Security': [
              'Succeeded'
            ]
          }
        }
        'Validate-SQL-Security': {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: 'https://management.azure.com/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Sql/servers?api-version=2023-05-01-preview'
            headers: {
              'Content-Type': 'application/json'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
          runAfter: {
            'Validate-Storage-Security': [
              'Succeeded'
            ]
          }
        }
        'Log-Security-Validation-Results': {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://${split(logAnalyticsWorkspaceId, '/')[8]}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01'
            headers: {
              'Content-Type': 'application/json'
              'Log-Type': 'SecurityValidation'
            }
            body: {
              timestamp: utcNow()
              environment: environment
              workload: workloadName
              validationStatus: 'Completed'
              securityBaseline: securityBaselineConfig
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
          runAfter: {
            'Validate-SQL-Security': [
              'Succeeded'
            ]
          }
        }
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Enhanced audit logging configuration for administrative operations
resource enhancedAuditLogDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableAuditLogging && !empty(logAnalyticsWorkspaceId)) {
  scope: resourceGroup()
  name: '${namingConvention.diagnosticSetting}-enhanced-audit'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'Administrative'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: securityBaselineConfig.auditRetentionDays
        }
      }
      {
        category: 'Security'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: securityBaselineConfig.auditRetentionDays
        }
      }
    ]
  }
}

// Security baseline monitoring alerts
resource securityBaselineAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enableSecurityBaseline && !empty(logAnalyticsWorkspaceId)) {
  name: '${namingConvention.diagnosticSetting}-security-baseline-alert'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when security baseline validation fails'
    severity: 2
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'SecurityValidationFailure'
          metricName: 'SecurityValidationFailure'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
        }
      ]
    }
    actions: [
      {
        actionGroupId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Insights/actionGroups/security-alerts'
        webHookProperties: {}
      }
    ]
  }
}

// Security baseline configuration output for use by other modules
output securityBaselineConfig object = securityBaselineConfig

output diagnosticSettingsTemplate object = diagnosticSettingsTemplate

output securityValidationFunction string = 'validateSecurityBaseline'

output auditLoggingEnabled bool = enableAuditLogging

output securityContactId string = enableSecurityBaseline ? securityContact.id : ''

output autoProvisioningEnabled bool = enableSecurityBaseline

output workspaceSettingsConfigured bool = enableSecurityBaseline && !empty(logAnalyticsWorkspaceId)

output securityValidationLogicAppId string = enableSecurityBaseline ? securityValidationLogicApp.id : ''

output securityBaselineAlertId string = enableSecurityBaseline && !empty(logAnalyticsWorkspaceId) ? securityBaselineAlert.id : ''

// Security baseline compliance status
output complianceStatus object = {
  httpsOnlyEnforced: securityBaselineConfig.requireHttpsOnly
  tlsVersionEnforced: securityBaselineConfig.requireTlsVersion
  advancedThreatProtectionEnabled: securityBaselineConfig.enableAdvancedThreatProtection
  privateEndpointsRequired: securityBaselineConfig.requirePrivateEndpoints
  auditLoggingConfigured: enableAuditLogging && !empty(logAnalyticsWorkspaceId)
  securityCenterConfigured: enableSecurityBaseline
  diagnosticSettingsEnabled: securityBaselineConfig.enableDiagnosticSettings
  securityValidationEnabled: enableSecurityBaseline
  enhancedAuditLoggingEnabled: enableAuditLogging && !empty(logAnalyticsWorkspaceId)
  securityAlertsConfigured: enableSecurityBaseline && !empty(logAnalyticsWorkspaceId)
}