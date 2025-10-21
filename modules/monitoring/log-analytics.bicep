// Log Analytics Workspace module
// This module implements Log Analytics workspace with retention policies,
// data collection rules, and workspace permissions

targetScope = 'resourceGroup'

// Import shared parameter schemas
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

// Parameters
@description('The name of the Log Analytics workspace')
param workspaceName string

@description('The location for the Log Analytics workspace')
param location string = resourceGroup().location

@description('The SKU of the Log Analytics workspace')
@allowed(['Free', 'Standard', 'Premium', 'PerNode', 'PerGB2018', 'Standalone', 'CapacityReservation'])
param workspaceSku string = 'PerGB2018'

@description('The data retention period in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('The daily quota for data ingestion in GB')
@minValue(1)
@maxValue(1000)
param dailyQuotaGb int = 10

@description('Enable public network access')
param enablePublicNetworkAccess bool = false

@description('Subnet IDs allowed to access the workspace')
param allowedSubnetIds array = []

@description('IP addresses allowed to access the workspace')
param allowedIpAddresses array = []

@description('Enable data export')
param enableDataExport bool = false

@description('Storage account ID for data export')
param dataExportStorageAccountId string = ''

@description('Tags to apply to the Log Analytics workspace')
param tags TagConfiguration

@description('Enable diagnostic settings for the workspace itself')
param enableDiagnosticSettings bool = true

@description('Diagnostic settings storage account ID')
param diagnosticStorageAccountId string = ''

// Variables
var workspaceConfig = {
  sku: {
    name: workspaceSku
  }
  retentionInDays: retentionInDays
  workspaceCapping: {
    dailyQuotaGb: dailyQuotaGb
  }
  publicNetworkAccessForIngestion: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
  publicNetworkAccessForQuery: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
}

// Network access control configuration
var ipRules = [for ip in allowedIpAddresses: {
  value: ip
  action: 'Allow'
}]

var virtualNetworkRules = [for subnetId in allowedSubnetIds: {
  id: subnetId
  action: 'Allow'
}]

var networkAccessControl = {
  defaultAction: 'Deny'
  ipRules: ipRules
  virtualNetworkRules: virtualNetworkRules
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: !enablePublicNetworkAccess ? union(workspaceConfig, {
    networkAccessControl: networkAccessControl
  }) : workspaceConfig
}

// Data Collection Rules for common log types
resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: '${workspaceName}-dcr'
  location: location
  tags: tags
  properties: {
    description: 'Data collection rule for ${workspaceName}'
    dataSources: {
      performanceCounters: [
        {
          name: 'perfCounterDataSource60'
          streams: ['Microsoft-Perf']
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\Processor(_Total)\\% Processor Time'
            '\\Memory\\Available MBytes'
            '\\LogicalDisk(_Total)\\Disk Reads/sec'
            '\\LogicalDisk(_Total)\\Disk Writes/sec'
            '\\LogicalDisk(_Total)\\% Free Space'
            '\\Network Interface(*)\\Bytes Total/sec'
          ]
        }
      ]
      windowsEventLogs: [
        {
          name: 'eventLogsDataSource'
          streams: ['Microsoft-Event']
          xPathQueries: [
            'Application!*[System[(Level=1 or Level=2 or Level=3)]]'
            'Security!*[System[(band(Keywords,13510798882111488))]]'
            'System!*[System[(Level=1 or Level=2 or Level=3)]]'
          ]
        }
      ]
      syslog: [
        {
          name: 'syslogDataSource'
          streams: ['Microsoft-Syslog']
          facilityNames: ['auth', 'authpriv', 'cron', 'daemon', 'kern', 'lpr', 'mail', 'mark', 'news', 'syslog', 'user', 'uucp']
          logLevels: ['Alert', 'Critical', 'Emergency', 'Error', 'Warning']
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: 'la-destination'
        }
      ]
    }
    dataFlows: [
      {
        streams: ['Microsoft-Perf']
        destinations: ['la-destination']
        transformKql: 'source'
        outputStream: 'Microsoft-Perf'
      }
      {
        streams: ['Microsoft-Event']
        destinations: ['la-destination']
        transformKql: 'source'
        outputStream: 'Microsoft-Event'
      }
      {
        streams: ['Microsoft-Syslog']
        destinations: ['la-destination']
        transformKql: 'source'
        outputStream: 'Microsoft-Syslog'
      }
    ]
  }
}

// Data Export Rule (if enabled)
resource dataExportRule 'Microsoft.OperationalInsights/workspaces/dataExports@2020-08-01' = if (enableDataExport && !empty(dataExportStorageAccountId)) {
  name: 'export-all-logs'
  parent: logAnalyticsWorkspace
  properties: {
    destination: {
      resourceId: dataExportStorageAccountId
      type: 'StorageAccount'
    }
    tableNames: [
      'Heartbeat'
      'Perf'
      'Event'
      'Syslog'
      'SecurityEvent'
      'AzureActivity'
      'AzureDiagnostics'
    ]
    enable: true
  }
}

// Workspace solutions for enhanced monitoring
resource securitySolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'Security(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
  plan: {
    name: 'Security(${logAnalyticsWorkspace.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/Security'
    promotionCode: ''
  }
}

resource updatesSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'Updates(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
  plan: {
    name: 'Updates(${logAnalyticsWorkspace.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/Updates'
    promotionCode: ''
  }
}

resource changeTrackingSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'ChangeTracking(${logAnalyticsWorkspace.name})'
  location: location
  tags: tags
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
  plan: {
    name: 'ChangeTracking(${logAnalyticsWorkspace.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/ChangeTracking'
    promotionCode: ''
  }
}

// Diagnostic settings for the workspace itself
resource workspaceDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnosticSettings && !empty(diagnosticStorageAccountId)) {
  name: '${workspaceName}-diagnostics'
  scope: logAnalyticsWorkspace
  properties: {
    storageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : null
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: retentionInDays
        }
      }
    ]
  }
}

// Outputs
@description('The resource ID of the Log Analytics workspace')
output workspaceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace')
output workspaceName string = logAnalyticsWorkspace.name

@description('The customer ID (workspace ID) of the Log Analytics workspace')
output customerId string = logAnalyticsWorkspace.properties.customerId

@description('The primary shared key of the Log Analytics workspace')
@secure()
output primarySharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey

@description('The secondary shared key of the Log Analytics workspace')
@secure()
output secondarySharedKey string = logAnalyticsWorkspace.listKeys().secondarySharedKey

@description('The resource ID of the data collection rule')
output dataCollectionRuleId string = dataCollectionRule.id

@description('The resource ID of the data export rule')
output dataExportRuleId string = enableDataExport && !empty(dataExportStorageAccountId) ? dataExportRule.id : ''

@description('The Log Analytics workspace configuration')
output workspaceConfig object = {
  id: logAnalyticsWorkspace.id
  name: logAnalyticsWorkspace.name
  customerId: logAnalyticsWorkspace.properties.customerId
  location: logAnalyticsWorkspace.location
  sku: logAnalyticsWorkspace.properties.sku.name
  retentionInDays: logAnalyticsWorkspace.properties.retentionInDays
  dailyQuotaGb: logAnalyticsWorkspace.properties.workspaceCapping.dailyQuotaGb
}