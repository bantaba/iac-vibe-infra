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

@description('Public IP addresses to associate with DDoS protection')
param publicIpAddresses array = []

@description('Virtual networks to associate with DDoS protection')
param virtualNetworks array = []

@description('Log Analytics workspace ID for DDoS monitoring')
param logAnalyticsWorkspaceId string = ''

@description('Enable DDoS protection telemetry')
param enableTelemetry bool = true

@description('DDoS protection policy configuration')
param ddosProtectionPolicy object = {
  ddosCustomPolicy: {
    protocolCustomSettings: [
      {
        protocol: 'Tcp'
        triggerRateOverride: '20000'
        sourceRateOverride: '10000'
        triggerSensitivityOverride: 'Relaxed'
      }
      {
        protocol: 'Udp'
        triggerRateOverride: '10000'
        sourceRateOverride: '5000'
        triggerSensitivityOverride: 'Default'
      }
      {
        protocol: 'Syn'
        triggerRateOverride: '15000'
        sourceRateOverride: '7500'
        triggerSensitivityOverride: 'Default'
      }
    ]
  }
}

// DDoS Protection Plan
resource ddosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2023-09-01' = if (enableDdosProtection) {
  name: ddosProtectionPlanName
  location: location
  tags: tags
  properties: {}
}

// DDoS Protection Policy (if custom policy is needed)
resource ddosProtectionPolicy_resource 'Microsoft.Network/ddosCustomPolicies@2023-09-01' = if (enableDdosProtection && !empty(ddosProtectionPolicy)) {
  name: '${ddosProtectionPlanName}-policy'
  location: location
  tags: tags
  properties: {
    protocolCustomSettings: ddosProtectionPolicy.ddosCustomPolicy.protocolCustomSettings
  }
}

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
output ddosProtectionPolicyId string = enableDdosProtection && !empty(ddosProtectionPolicy) ? ddosProtectionPolicy_resource.id : ''

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