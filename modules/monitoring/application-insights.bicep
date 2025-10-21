// Application Insights module
// This module creates Application Insights for application performance monitoring
// with custom metrics, availability tests, and Log Analytics integration

targetScope = 'resourceGroup'

// Import shared parameter schemas
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

// Parameters
@description('The name of the Application Insights instance')
param applicationInsightsName string

@description('The location for Application Insights')
param location string = resourceGroup().location

@description('The type of application being monitored')
@allowed(['web', 'other'])
param applicationType string = 'web'

@description('The resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string

@description('Enable public network access for ingestion')
param enablePublicNetworkAccessForIngestion bool = false

@description('Enable public network access for query')
param enablePublicNetworkAccessForQuery bool = false

@description('Data retention period in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

@description('Daily data cap in GB')
@minValue(1)
@maxValue(1000)
param dailyDataCapInGB int = 10

@description('Enable daily data cap reset')
param enableDailyDataCapReset bool = true

@description('Sampling percentage for telemetry')
@minValue(0)
@maxValue(100)
param samplingPercentage int = 100

@description('Enable request source correlation')
param enableRequestSource bool = true

@description('URLs to monitor with availability tests')
param availabilityTestUrls array = []

@description('Locations for availability tests')
param availabilityTestLocations array = [
  'us-east-1'
  'us-west-1'
  'europe-west-1'
  'asia-southeast-1'
  'australia-east-1'
]

@description('Enable custom metrics and events')
param enableCustomMetrics bool = true

@description('Enable live metrics stream')
param enableLiveMetrics bool = true

@description('Enable profiler')
param enableProfiler bool = false

@description('Enable snapshot debugger')
param enableSnapshotDebugger bool = false

@description('Tags to apply to Application Insights')
param tags TagConfiguration

// Variables
var workspaceResourceId = logAnalyticsWorkspaceId

// Application Insights instance
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: applicationType
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: workspaceResourceId
    publicNetworkAccessForIngestion: enablePublicNetworkAccessForIngestion ? 'Enabled' : 'Disabled'
    publicNetworkAccessForQuery: enablePublicNetworkAccessForQuery ? 'Enabled' : 'Disabled'
    RetentionInDays: retentionInDays
    IngestionMode: 'LogAnalytics'
    SamplingPercentage: samplingPercentage
    DisableIpMasking: false
    DisableLocalAuth: true
  }
}

// Data cap configuration
resource dataCapConfig 'Microsoft.Insights/components/pricingPlans@2017-10-01' = {
  name: 'current'
  parent: applicationInsights
  properties: {
    cap: dailyDataCapInGB
    warningThreshold: 80
    stopSendNotificationWhenHitCap: false
  }
}

// Availability tests for each URL
resource availabilityTests 'Microsoft.Insights/webtests@2022-06-15' = [for (url, i) in availabilityTestUrls: {
  name: '${applicationInsightsName}-availability-test-${i}'
  location: location
  tags: union(tags, {
    'hidden-link:${applicationInsights.id}': 'Resource'
  })
  properties: {
    SyntheticMonitorId: '${applicationInsightsName}-availability-test-${i}'
    Name: 'Availability Test - ${url}'
    Description: 'Availability test for ${url}'
    Enabled: true
    Frequency: 300 // 5 minutes
    Timeout: 30
    Kind: 'ping'
    RetryEnabled: true
    Locations: [for location in availabilityTestLocations: {
      Id: location
    }]
    Configuration: {
      WebTest: '<WebTest Name="Availability Test - ${url}" Id="${guid(url)}" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="30" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale=""><Items><Request Method="GET" Guid="${guid(url, 'request')}" Version="1.1" Url="${url}" ThinkTime="0" Timeout="30" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" /></Items></WebTest>'
    }
  }
}]

// Custom metrics and events configuration
resource customMetricsConfig 'Microsoft.Insights/components/analyticsItems@2015-05-01' = if (enableCustomMetrics) {
  name: 'item'
  parent: applicationInsights
  properties: {
    name: 'Custom Metrics Configuration'
    type: 'query'
    scope: 'shared'
    content: '''
// Custom metrics queries for application monitoring
let customMetrics = () {
    customMetrics
    | where name in ("BusinessMetric1", "BusinessMetric2", "PerformanceCounter")
    | summarize avg(value) by name, bin(timestamp, 5m)
};
let errorRates = () {
    requests
    | summarize ErrorRate = (countif(success == false) * 100.0) / count() by bin(timestamp, 5m)
    | where ErrorRate > 5
};
let responseTimePercentiles = () {
    requests
    | summarize 
        P50 = percentile(duration, 50),
        P95 = percentile(duration, 95),
        P99 = percentile(duration, 99)
    by bin(timestamp, 5m)
};
union customMetrics(), errorRates(), responseTimePercentiles()
'''
  }
}

// Live metrics configuration
resource liveMetricsConfig 'Microsoft.Insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = if (enableLiveMetrics) {
  name: 'extension_traceseveritydetector'
  parent: applicationInsights
  properties: {
    enabled: true
    sendEmailsToSubscriptionOwners: true
    customEmails: []
  }
}

// Profiler configuration (if enabled)
resource profilerConfig 'Microsoft.Insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = if (enableProfiler) {
  name: 'extension_exceptionchangeextension'
  parent: applicationInsights
  properties: {
    enabled: true
    sendEmailsToSubscriptionOwners: false
    customEmails: []
  }
}

// Snapshot debugger configuration (if enabled)
resource snapshotDebuggerConfig 'Microsoft.Insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = if (enableSnapshotDebugger) {
  name: 'extension_memoryleakextension'
  parent: applicationInsights
  properties: {
    enabled: true
    sendEmailsToSubscriptionOwners: false
    customEmails: []
  }
}

// Application Insights API keys for programmatic access
resource apiKey 'Microsoft.Insights/components/ApiKeys@2015-05-01' = {
  name: '${applicationInsightsName}-api-key'
  parent: applicationInsights
  properties: {
    name: '${applicationInsightsName}-api-key'
    linkedReadProperties: [
      applicationInsights.id
    ]
    linkedWriteProperties: []
  }
}

// Continuous export configuration (optional)
resource continuousExport 'Microsoft.Insights/components/exportconfigurations@2015-05-01' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'continuous-export-config'
  parent: applicationInsights
  properties: {
    ExportId: guid(applicationInsights.id, 'export')
    ExportStatus: 'Enabled'
    InstrumentationKey: applicationInsights.properties.InstrumentationKey
    RecordTypes: 'Requests,Event,Exception,Metric,PageView,PageViewPerformance,Rdd,PerformanceCounter,Availability'
    ApplicationName: applicationInsightsName
    SubscriptionId: subscription().subscriptionId
    ResourceGroupName: resourceGroup().name
    DestinationType: 'Blob'
    IsUserEnabled: false
  }
}

// Outputs
@description('The resource ID of the Application Insights instance')
output applicationInsightsId string = applicationInsights.id

@description('The name of the Application Insights instance')
output applicationInsightsName string = applicationInsights.name

@description('The instrumentation key for Application Insights')
@secure()
output instrumentationKey string = applicationInsights.properties.InstrumentationKey

@description('The connection string for Application Insights')
@secure()
output connectionString string = applicationInsights.properties.ConnectionString

@description('The App ID for Application Insights')
output appId string = applicationInsights.properties.AppId

@description('The API key for programmatic access')
@secure()
output apiKey string = apiKey.properties.ApiKey

@description('The resource IDs of availability tests')
output availabilityTestIds array = [for (url, i) in availabilityTestUrls: availabilityTests[i].id]

@description('The Application Insights configuration')
output applicationInsightsConfig object = {
  id: applicationInsights.id
  name: applicationInsights.name
  appId: applicationInsights.properties.AppId
  location: applicationInsights.location
  applicationType: applicationType
  workspaceResourceId: workspaceResourceId
  retentionInDays: retentionInDays
  dailyDataCapInGB: dailyDataCapInGB
  samplingPercentage: samplingPercentage
  availabilityTestCount: length(availabilityTestUrls)
  customMetricsEnabled: enableCustomMetrics
  liveMetricsEnabled: enableLiveMetrics
  profilerEnabled: enableProfiler
  snapshotDebuggerEnabled: enableSnapshotDebugger
}