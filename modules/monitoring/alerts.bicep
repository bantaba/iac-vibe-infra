// Monitoring Alerts module
// This module implements security and performance alerts with action groups
// and notification channels for comprehensive monitoring

targetScope = 'resourceGroup'

// Import shared parameter schemas
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

// Parameters
@description('The prefix for alert rule names')
param alertNamePrefix string

@description('The location for alert resources')
param location string = resourceGroup().location

@description('The resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string

@description('The resource ID of the Application Insights instance')
param applicationInsightsId string = ''

@description('Email addresses for alert notifications')
param alertEmailAddresses array = []

@description('SMS phone numbers for critical alerts')
param alertSmsNumbers array = []

@description('Webhook URLs for alert notifications')
param alertWebhookUrls array = []

@description('Enable security alerts')
param enableSecurityAlerts bool = true

@description('Enable performance alerts')
param enablePerformanceAlerts bool = true

@description('Enable availability alerts')
param enableAvailabilityAlerts bool = true

@description('Resource IDs to monitor for alerts')
param monitoredResourceIds array = []

@description('Tags to apply to alert resources')
param tags TagConfiguration

// Variables
var actionGroupName = '${alertNamePrefix}-action-group'
var criticalActionGroupName = '${alertNamePrefix}-critical-action-group'

// Action Group for general alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: substring(actionGroupName, 0, min(length(actionGroupName), 12))
    enabled: true
    emailReceivers: [for (email, i) in alertEmailAddresses: {
      name: 'email-${i}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
    smsReceivers: [for (sms, i) in alertSmsNumbers: {
      name: 'sms-${i}'
      countryCode: '1'
      phoneNumber: sms
    }]
    webhookReceivers: [for (webhook, i) in alertWebhookUrls: {
      name: 'webhook-${i}'
      serviceUri: webhook
      useCommonAlertSchema: true
    }]
  }
}

// Action Group for critical alerts (includes SMS)
resource criticalActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: criticalActionGroupName
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: substring(criticalActionGroupName, 0, min(length(criticalActionGroupName), 12))
    enabled: true
    emailReceivers: [for (email, i) in alertEmailAddresses: {
      name: 'email-${i}'
      emailAddress: email
      useCommonAlertSchema: true
    }]
    smsReceivers: [for (sms, i) in alertSmsNumbers: {
      name: 'sms-${i}'
      countryCode: '1'
      phoneNumber: sms
    }]
    webhookReceivers: [for (webhook, i) in alertWebhookUrls: {
      name: 'webhook-${i}'
      serviceUri: webhook
      useCommonAlertSchema: true
    }]
  }
}

// Security Alert Rules
resource securityFailedLoginsAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enableSecurityAlerts && !empty(logAnalyticsWorkspaceId)) {
  name: '${alertNamePrefix}-security-failed-logins'
  location: location
  tags: tags
  properties: {
    displayName: 'Security - Multiple Failed Login Attempts'
    description: 'Alert when there are multiple failed login attempts from the same IP'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'SecurityEvent | where EventID == 4625 | summarize FailedAttempts = count() by IpAddress | where FailedAttempts > 5'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'IpAddress'
              operator: 'Include'
              values: ['*']
            }
          ]
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        criticalActionGroup.id
      ]
    }
    scopes: [
      logAnalyticsWorkspaceId
    ]
  }
}

resource securityPrivilegeEscalationAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enableSecurityAlerts && !empty(logAnalyticsWorkspaceId)) {
  name: '${alertNamePrefix}-security-privilege-escalation'
  location: location
  tags: tags
  properties: {
    displayName: 'Security - Privilege Escalation Detected'
    description: 'Alert when privilege escalation activities are detected'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'SecurityEvent | where EventID in (4672, 4673, 4674) | summarize count() by Account'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'Account'
              operator: 'Include'
              values: ['*']
            }
          ]
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        criticalActionGroup.id
      ]
    }
    scopes: [
      logAnalyticsWorkspaceId
    ]
  }
}

// Performance Alert Rules
resource performanceCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enablePerformanceAlerts && !empty(monitoredResourceIds)) {
  name: '${alertNamePrefix}-performance-high-cpu'
  location: 'Global'
  tags: tags
  properties: {
    displayName: 'Performance - High CPU Usage'
    description: 'Alert when CPU usage exceeds 80% for 10 minutes'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1M'
    windowSize: 'PT10M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'Percentage CPU'
          metricNamespace: 'Microsoft.Compute/virtualMachines'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
    scopes: monitoredResourceIds
  }
}

resource performanceMemoryAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enablePerformanceAlerts && !empty(logAnalyticsWorkspaceId)) {
  name: '${alertNamePrefix}-performance-low-memory'
  location: location
  tags: tags
  properties: {
    displayName: 'Performance - Low Available Memory'
    description: 'Alert when available memory is below 10% for 5 minutes'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'Perf | where ObjectName == "Memory" and CounterName == "Available MBytes" | summarize AvgMemory = avg(CounterValue) by Computer | where AvgMemory < 1024'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: ['*']
            }
          ]
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
    scopes: [
      logAnalyticsWorkspaceId
    ]
  }
}

resource performanceDiskSpaceAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enablePerformanceAlerts && !empty(logAnalyticsWorkspaceId)) {
  name: '${alertNamePrefix}-performance-low-disk-space'
  location: location
  tags: tags
  properties: {
    displayName: 'Performance - Low Disk Space'
    description: 'Alert when disk free space is below 10%'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'Perf | where ObjectName == "LogicalDisk" and CounterName == "% Free Space" | summarize AvgFreeSpace = avg(CounterValue) by Computer, InstanceName | where AvgFreeSpace < 10'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: ['*']
            }
            {
              name: 'InstanceName'
              operator: 'Include'
              values: ['*']
            }
          ]
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
    scopes: [
      logAnalyticsWorkspaceId
    ]
  }
}

// Availability Alert Rules
resource availabilityApplicationInsightsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enableAvailabilityAlerts && !empty(applicationInsightsId)) {
  name: '${alertNamePrefix}-availability-app-insights'
  location: 'Global'
  tags: tags
  properties: {
    displayName: 'Availability - Application Insights Availability'
    description: 'Alert when application availability drops below 95%'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'LowAvailability'
          metricName: 'availabilityResults/availabilityPercentage'
          metricNamespace: 'Microsoft.Insights/components'
          operator: 'LessThan'
          threshold: 95
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: criticalActionGroup.id
      }
    ]
    scopes: [
      applicationInsightsId
    ]
  }
}

resource availabilityResponseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (enableAvailabilityAlerts && !empty(applicationInsightsId)) {
  name: '${alertNamePrefix}-availability-response-time'
  location: 'Global'
  tags: tags
  properties: {
    displayName: 'Availability - High Response Time'
    description: 'Alert when average response time exceeds 5 seconds'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighResponseTime'
          metricName: 'requests/duration'
          metricNamespace: 'Microsoft.Insights/components'
          operator: 'GreaterThan'
          threshold: 5000
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
    scopes: [
      applicationInsightsId
    ]
  }
}

// Database-specific alerts
resource databaseConnectionAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = if (enablePerformanceAlerts && !empty(logAnalyticsWorkspaceId)) {
  name: '${alertNamePrefix}-database-connection-failures'
  location: location
  tags: tags
  properties: {
    displayName: 'Database - Connection Failures'
    description: 'Alert when database connection failures exceed threshold'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'AzureDiagnostics | where ResourceProvider == "MICROSOFT.SQL" and Category == "Errors" | summarize ErrorCount = count() by Resource | where ErrorCount > 10'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'Resource'
              operator: 'Include'
              values: ['*']
            }
          ]
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
    scopes: [
      logAnalyticsWorkspaceId
    ]
  }
}

// Outputs
@description('The resource ID of the general action group')
output actionGroupId string = actionGroup.id

@description('The resource ID of the critical action group')
output criticalActionGroupId string = criticalActionGroup.id

@description('The resource IDs of all created alert rules')
output alertRuleIds array = [
  enableSecurityAlerts && !empty(logAnalyticsWorkspaceId) ? securityFailedLoginsAlert.id : ''
  enableSecurityAlerts && !empty(logAnalyticsWorkspaceId) ? securityPrivilegeEscalationAlert.id : ''
  enablePerformanceAlerts && !empty(monitoredResourceIds) ? performanceCpuAlert.id : ''
  enablePerformanceAlerts && !empty(logAnalyticsWorkspaceId) ? performanceMemoryAlert.id : ''
  enablePerformanceAlerts && !empty(logAnalyticsWorkspaceId) ? performanceDiskSpaceAlert.id : ''
  enableAvailabilityAlerts && !empty(applicationInsightsId) ? availabilityApplicationInsightsAlert.id : ''
  enableAvailabilityAlerts && !empty(applicationInsightsId) ? availabilityResponseTimeAlert.id : ''
  enablePerformanceAlerts && !empty(logAnalyticsWorkspaceId) ? databaseConnectionAlert.id : ''
]

@description('The monitoring alerts configuration')
output alertsConfig object = {
  actionGroupId: actionGroup.id
  criticalActionGroupId: criticalActionGroup.id
  securityAlertsEnabled: enableSecurityAlerts
  performanceAlertsEnabled: enablePerformanceAlerts
  availabilityAlertsEnabled: enableAvailabilityAlerts
  alertRuleCount: length(filter([
    enableSecurityAlerts && !empty(logAnalyticsWorkspaceId) ? 'security1' : ''
    enableSecurityAlerts && !empty(logAnalyticsWorkspaceId) ? 'security2' : ''
    enablePerformanceAlerts && !empty(monitoredResourceIds) ? 'perf1' : ''
    enablePerformanceAlerts && !empty(logAnalyticsWorkspaceId) ? 'perf2' : ''
    enablePerformanceAlerts && !empty(logAnalyticsWorkspaceId) ? 'perf3' : ''
    enableAvailabilityAlerts && !empty(applicationInsightsId) ? 'avail1' : ''
    enableAvailabilityAlerts && !empty(applicationInsightsId) ? 'avail2' : ''
    enablePerformanceAlerts && !empty(logAnalyticsWorkspaceId) ? 'db1' : ''
  ], item => !empty(item)))
}