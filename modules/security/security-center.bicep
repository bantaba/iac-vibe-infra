// Security Center module
// This module implements Azure Security Center (Microsoft Defender for Cloud) configuration

targetScope = 'subscription'

// Import shared types
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

// Required parameters
@description('The subscription ID for Security Center configuration')
param subscriptionId string = subscription().subscriptionId

@description('Tags to apply to all resources')
param tags TagConfiguration

// Configuration parameters
@description('Enable Microsoft Defender for Cloud plans')
param enableDefenderPlans bool = true

@description('Microsoft Defender for Cloud plans to enable')
param defenderPlans array = [
  {
    name: 'VirtualMachines'
    tier: 'Standard'
    subPlan: 'P2'
  }
  {
    name: 'AppServices'
    tier: 'Standard'
    subPlan: null
  }
  {
    name: 'SqlServers'
    tier: 'Standard'
    subPlan: null
  }
  {
    name: 'SqlServerVirtualMachines'
    tier: 'Standard'
    subPlan: null
  }
  {
    name: 'StorageAccounts'
    tier: 'Standard'
    subPlan: 'DefenderForStorageV2'
  }
  {
    name: 'KeyVaults'
    tier: 'Standard'
    subPlan: null
  }
  {
    name: 'Arm'
    tier: 'Standard'
    subPlan: null
  }
  {
    name: 'OpenSourceRelationalDatabases'
    tier: 'Standard'
    subPlan: null
  }
  {
    name: 'Containers'
    tier: 'Standard'
    subPlan: null
  }
  {
    name: 'CloudPosture'
    tier: 'Standard'
    subPlan: null
  }
]

@description('Security contacts configuration')
param securityContacts array = [
  {
    email: 'security@contoso.com'
    phone: '+1-555-0123'
    alertNotifications: 'On'
    notificationsByRole: 'On'
  }
]

@description('Auto provisioning settings')
param autoProvisioningSettings object = {
  logAnalytics: 'On'
  microsoftDefenderForEndpoint: 'On'
  vulnerabilityAssessment: 'On'
  guestConfiguration: 'On'
}

@description('Log Analytics workspace ID for Security Center integration')
param logAnalyticsWorkspaceId string = ''

@description('Enable telemetry for the module')
param enableTelemetry bool = true

// Variables
var workspaceSettings = !empty(logAnalyticsWorkspaceId) ? {
  workspaceId: logAnalyticsWorkspaceId
  scope: subscriptionId
} : null

// Enable Microsoft Defender for Cloud plans
resource defenderForCloudPlans 'Microsoft.Security/pricings@2024-01-01' = [for plan in defenderPlans: if (enableDefenderPlans) {
  name: plan.name
  properties: {
    pricingTier: plan.tier
    subPlan: plan.subPlan
  }
}]

// Configure security contacts
resource securityContactsConfig 'Microsoft.Security/securityContacts@2020-01-01-preview' = [for (contact, i) in securityContacts: {
  name: 'default${i + 1}'
  properties: {
    emails: contact.email
    phone: contact.phone
    alertNotifications: {
      state: contact.alertNotifications
      minimalSeverity: 'Medium'
    }
    notificationsByRole: {
      state: contact.notificationsByRole
      roles: ['Owner', 'Contributor']
    }
  }
}]

// Configure auto provisioning settings
resource autoProvisioningLogAnalytics 'Microsoft.Security/autoProvisioningSettings@2017-08-01-preview' = if (autoProvisioningSettings.logAnalytics == 'On') {
  name: 'default'
  properties: {
    autoProvision: autoProvisioningSettings.logAnalytics
  }
}

// Configure workspace settings for Log Analytics integration
resource workspaceSettingsConfig 'Microsoft.Security/workspaceSettings@2017-08-01-preview' = if (workspaceSettings != null) {
  name: 'default'
  properties: {
    workspaceId: workspaceSettings!.workspaceId
    scope: workspaceSettings!.scope
  }
}

// Configure security policies and initiatives
resource securityPolicyAssignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'ASC-Default-${uniqueString(subscriptionId)}'
  properties: {
    displayName: 'Azure Security Benchmark'
    description: 'Azure Security Benchmark initiative for Microsoft Defender for Cloud'
    policyDefinitionId: '/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8'
    parameters: {}
    metadata: {
      assignedBy: 'Bicep Template'
      category: 'Security Center'
    }
  }
}

// Configure additional security assessments
resource customSecurityAssessments 'Microsoft.Security/assessmentMetadata@2021-06-01' = {
  name: 'custom-security-assessment-${uniqueString(subscriptionId)}'
  properties: {
    displayName: 'Custom Security Assessment for ${tags.Workload}'
    description: 'Custom security assessment for workload-specific security requirements'
    severity: 'Medium'
    assessmentType: 'CustomerManaged'
    categories: ['Compute', 'Data', 'Networking']
    userImpact: 'Moderate'
    implementationEffort: 'Moderate'
  }
}

// Telemetry deployment (optional)
resource telemetryDeployment 'Microsoft.Resources/deployments@2022-09-01' = if (enableTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

// Outputs
@description('Microsoft Defender for Cloud plan configurations')
output defenderPlansConfig array = [for (plan, i) in defenderPlans: {
  name: plan.name
  tier: defenderForCloudPlans[i].properties.pricingTier
  subPlan: defenderForCloudPlans[i].properties.subPlan
  resourceId: defenderForCloudPlans[i].id
}]

@description('Security contacts configuration')
output securityContactsConfig array = [for (contact, i) in securityContacts: {
  name: securityContactsConfig[i].name
  email: contact.email
  phone: contact.phone
  resourceId: securityContactsConfig[i].id
}]

@description('Auto provisioning settings')
output autoProvisioningConfig object = {
  logAnalytics: autoProvisioningSettings.logAnalytics
  resourceId: autoProvisioningLogAnalytics.id
}

@description('Workspace settings configuration')
output workspaceSettingsConfig object = workspaceSettings != null ? {
  workspaceId: workspaceSettings!.workspaceId
  scope: workspaceSettings!.scope
  resourceId: workspaceSettingsConfig.id
} : {
  workspaceId: ''
  scope: ''
  resourceId: ''
}

@description('Security policy assignment information')
output securityPolicyAssignment object = {
  name: securityPolicyAssignment.name
  displayName: securityPolicyAssignment.properties.displayName
  policyDefinitionId: securityPolicyAssignment.properties.policyDefinitionId
  resourceId: securityPolicyAssignment.id
}

@description('Custom security assessment information')
output customSecurityAssessment object = {
  name: customSecurityAssessments.name
  displayName: customSecurityAssessments.properties.displayName
  severity: customSecurityAssessments.properties.severity
  resourceId: customSecurityAssessments.id
}

@description('Security Center configuration summary')
output securityCenterConfig object = {
  subscriptionId: subscriptionId
  defenderPlansEnabled: enableDefenderPlans
  defenderPlansCount: length(defenderPlans)
  securityContactsCount: length(securityContacts)
  logAnalyticsIntegration: workspaceSettings != null
  autoProvisioningEnabled: autoProvisioningSettings.logAnalytics == 'On'
}