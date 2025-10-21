// Diagnostic Settings module
// This module creates diagnostic settings for Azure resources to forward logs
// and metrics to Log Analytics workspace, Storage Account, and Event Hub

targetScope = 'resourceGroup'



// Parameters
@description('The name of the diagnostic setting')
param diagnosticSettingName string

@description('The resource ID of the target resource to configure diagnostics for')
param targetResourceId string

@description('The resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string = ''

@description('The resource ID of the Storage Account for log archival')
param storageAccountId string = ''

@description('The resource ID of the Event Hub for log streaming')
param eventHubAuthorizationRuleId string = ''

@description('The name of the Event Hub')
param eventHubName string = ''

@description('Log retention period in days for storage account')
@minValue(1)
@maxValue(365)
param logRetentionDays int = 90

@description('Metric retention period in days for storage account')
@minValue(1)
@maxValue(365)
param metricRetentionDays int = 90

@description('Enable all log categories')
param enableAllLogs bool = true

@description('Enable all metrics')
param enableAllMetrics bool = true

@description('Specific log categories to enable (if enableAllLogs is false)')
param logCategories array = []



// Variables
var hasLogAnalytics = !empty(logAnalyticsWorkspaceId)
var hasStorageAccount = !empty(storageAccountId)
var hasEventHub = !empty(eventHubAuthorizationRuleId) && !empty(eventHubName)

// Validate that at least one destination is provided
var hasDestination = hasLogAnalytics || hasStorageAccount || hasEventHub

// Common log categories for different resource types
var commonLogCategories = {
  'Microsoft.KeyVault/vaults': [
    'AuditEvent'
    'AzurePolicyEvaluationDetails'
  ]
  'Microsoft.Storage/storageAccounts': [
    'StorageRead'
    'StorageWrite'
    'StorageDelete'
  ]
  'Microsoft.Sql/servers/databases': [
    'SQLInsights'
    'AutomaticTuning'
    'QueryStoreRuntimeStatistics'
    'QueryStoreWaitStatistics'
    'Errors'
    'DatabaseWaitStatistics'
    'Timeouts'
    'Blocks'
    'Deadlocks'
  ]
  'Microsoft.Network/applicationGateways': [
    'ApplicationGatewayAccessLog'
    'ApplicationGatewayPerformanceLog'
    'ApplicationGatewayFirewallLog'
  ]
  'Microsoft.Network/loadBalancers': [
    'LoadBalancerAlertEvent'
    'LoadBalancerProbeHealthStatus'
  ]
  'Microsoft.Network/networkSecurityGroups': [
    'NetworkSecurityGroupEvent'
    'NetworkSecurityGroupRuleCounter'
  ]
  'Microsoft.Network/virtualNetworks': [
    'VMProtectionAlerts'
  ]
  'Microsoft.Compute/virtualMachines': [
    'Microsoft-Windows-Kernel-Process/Analytic'
    'Microsoft-Windows-Kernel-Network/Analytic'
  ]
}

// Get resource type from resource ID
var resourceTypeParts = split(targetResourceId, '/')
var resourceType = length(resourceTypeParts) > 7 ? '${resourceTypeParts[6]}/${resourceTypeParts[7]}' : 'Unknown'
var defaultLogCategories = contains(commonLogCategories, resourceType) ? commonLogCategories[resourceType] : []



// Diagnostic Settings
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (hasDestination) {
  name: diagnosticSettingName
  scope: resourceGroup()
  properties: {
    workspaceId: hasLogAnalytics ? logAnalyticsWorkspaceId : null
    storageAccountId: hasStorageAccount ? storageAccountId : null
    eventHubAuthorizationRuleId: hasEventHub ? eventHubAuthorizationRuleId : null
    eventHubName: hasEventHub ? eventHubName : null
    logs: enableAllLogs ? [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: hasStorageAccount ? {
          enabled: true
          days: logRetentionDays
        } : null
      }
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: hasStorageAccount ? {
          enabled: true
          days: logRetentionDays
        } : null
      }
    ] : []
    metrics: enableAllMetrics ? [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: hasStorageAccount ? {
          enabled: true
          days: metricRetentionDays
        } : null
      }
    ] : []
  }
}

// Outputs
@description('The resource ID of the diagnostic setting')
output diagnosticSettingId string = hasDestination ? diagnosticSetting.id : ''

@description('The name of the diagnostic setting')
output diagnosticSettingName string = hasDestination ? diagnosticSetting.name : ''

@description('The configuration of the diagnostic setting')
output diagnosticSettingConfig object = hasDestination ? {
  id: diagnosticSetting.id
  name: diagnosticSetting.name
  targetResourceId: targetResourceId
  workspaceId: hasLogAnalytics ? logAnalyticsWorkspaceId : ''
  storageAccountId: hasStorageAccount ? storageAccountId : ''
  eventHubAuthorizationRuleId: hasEventHub ? eventHubAuthorizationRuleId : ''
  eventHubName: hasEventHub ? eventHubName : ''
  logRetentionDays: logRetentionDays
  metricRetentionDays: metricRetentionDays
} : {}