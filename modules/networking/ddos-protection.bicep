// DDoS Protection module
// This module creates DDoS protection plan for public-facing resources
// Configures DDoS protection policies and monitoring for enhanced security

targetScope = 'resourceGroup'

// Import shared modules
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

@description('The name of the DDoS protection plan')
param ddosProtectionPlanName string

@description('Tags to apply to all resources')
param tags TagConfiguration

@description('Location for the DDoS protection plan')
param location string = resourceGroup().location

@description('Enable DDoS protection plan')
param enableDdosProtection bool = true



@description('Log Analytics workspace ID for DDoS monitoring')
param logAnalyticsWorkspaceId string = ''

@description('Enable DDoS protection telemetry')
param enableTelemetry bool = true



// DDoS Protection Plan
resource ddosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2023-09-01' = if (enableDdosProtection) {
  name: ddosProtectionPlanName
  location: location
  tags: tags
  properties: {}
}

// Note: DDoS Custom Policies are not commonly used and have limited API support
// The DDoS Protection Plan provides standard protection without custom policies

// Diagnostic Settings for DDoS Protection Plan
resource ddosProtectionPlanDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDdosProtection && !empty(logAnalyticsWorkspaceId)) {
  name: '${ddosProtectionPlanName}-diagnostics'
  scope: ddosProtectionPlan
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

// Outputs
@description('The resource ID of the DDoS protection plan')
output ddosProtectionPlanId string = enableDdosProtection ? ddosProtectionPlan.id : ''

@description('The name of the DDoS protection plan')
output ddosProtectionPlanName string = enableDdosProtection ? ddosProtectionPlan.name : ''

@description('The resource ID of the DDoS protection policy')
output ddosProtectionPolicyId string = ''

@description('DDoS protection configuration for virtual networks')
output ddosProtectionConfig object = enableDdosProtection ? {
  id: ddosProtectionPlan.id
  enabled: true
} : {
  id: ''
  enabled: false
}

@description('DDoS protection monitoring configuration')
output monitoringConfig object = {
  ddosProtectionPlanId: enableDdosProtection ? ddosProtectionPlan.id : ''
  logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  telemetryEnabled: enableTelemetry
  diagnosticsEnabled: !empty(logAnalyticsWorkspaceId)
}