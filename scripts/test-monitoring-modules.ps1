# Monitoring Modules Unit Tests
# This script validates Log Analytics Workspace, Application Insights, Alerts, and Diagnostic Settings configurations
# Tests core functionality including workspace configuration, alert rules, and monitoring integration

param(
    [Parameter(Mandatory=$false)]
    [string]$TestScope = "All",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput
)

# Test configuration
$ErrorActionPreference = "Stop"
$testResults = @()

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    $result = @{
        TestName = $TestName
        Passed = $Passed
        Message = $Message
        Timestamp = Get-Date
    }
    
    $script:testResults += $result
    
    if ($Passed) {
        Write-Host "✓ $TestName" -ForegroundColor Green
    } else {
        Write-Host "✗ $TestName - $Message" -ForegroundColor Red
    }
    
    if ($VerboseOutput -and $Message) {
        Write-Host "  Details: $Message" -ForegroundColor Gray
    }
}

function Test-LogAnalyticsModule {
    Write-Host "`nTesting Log Analytics Workspace Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/monitoring/log-analytics.bicep" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Log Analytics template syntax" $true
        } else {
            Write-TestResult "Log Analytics template syntax" $false "Build failed: $buildResult"
        }
    } catch {
        Write-TestResult "Log Analytics template syntax" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 2: Validate workspace SKU options
    try {
        $templateContent = Get-Content "modules/monitoring/log-analytics.bicep" -Raw
        $validSkus = @('Free', 'Standard', 'Premium', 'PerNode', 'PerGB2018', 'Standalone', 'CapacityReservation')
        $skuValidation = $true
        foreach ($sku in $validSkus) {
            if ($templateContent -notmatch $sku) {
                $skuValidation = $false
                break
            }
        }
        Write-TestResult "Log Analytics workspace SKU validation" $skuValidation "All required SKUs are supported"
    } catch {
        Write-TestResult "Log Analytics workspace SKU validation" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 3: Validate retention policy configuration
    try {
        $templateContent = Get-Content "modules/monitoring/log-analytics.bicep" -Raw
        $hasRetentionConfig = $templateContent -match "retentionInDays" -and $templateContent -match "@minValue\(30\)" -and $templateContent -match "@maxValue\(730\)"
        Write-TestResult "Log Analytics retention policy configuration" $hasRetentionConfig "Retention policy properly configured with min/max values"
    } catch {
        Write-TestResult "Log Analytics retention policy configuration" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 4: Validate data collection rules
    try {
        $templateContent = Get-Content "modules/monitoring/log-analytics.bicep" -Raw
        $hasDataCollectionRules = $templateContent -match "Microsoft.Insights/dataCollectionRules" -and $templateContent -match "performanceCounters" -and $templateContent -match "windowsEventLogs"
        Write-TestResult "Log Analytics data collection rules" $hasDataCollectionRules "Data collection rules for performance counters and event logs configured"
    } catch {
        Write-TestResult "Log Analytics data collection rules" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 5: Validate network access controls
    try {
        $templateContent = Get-Content "modules/monitoring/log-analytics.bicep" -Raw
        $hasNetworkControls = $templateContent -match "publicNetworkAccessForIngestion" -and $templateContent -match "publicNetworkAccessForQuery" -and $templateContent -match "networkAccessControl"
        Write-TestResult "Log Analytics network access controls" $hasNetworkControls "Network access controls properly configured"
    } catch {
        Write-TestResult "Log Analytics network access controls" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 6: Validate workspace solutions
    try {
        $templateContent = Get-Content "modules/monitoring/log-analytics.bicep" -Raw
        $hasSolutions = $templateContent -match "Microsoft.OperationsManagement/solutions" -and $templateContent -match "Security" -and $templateContent -match "Updates" -and $templateContent -match "ChangeTracking"
        Write-TestResult "Log Analytics workspace solutions" $hasSolutions "Security, Updates, and ChangeTracking solutions configured"
    } catch {
        Write-TestResult "Log Analytics workspace solutions" $false "Exception: $($_.Exception.Message)"
    }
}

function Test-ApplicationInsightsModule {
    Write-Host "`nTesting Application Insights Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/monitoring/application-insights.bicep" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Application Insights template syntax" $true
        } else {
            Write-TestResult "Application Insights template syntax" $false "Build failed: $buildResult"
        }
    } catch {
        Write-TestResult "Application Insights template syntax" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 2: Validate Log Analytics workspace integration
    try {
        $templateContent = Get-Content "modules/monitoring/application-insights.bicep" -Raw
        $hasWorkspaceIntegration = $templateContent -match "WorkspaceResourceId" -and $templateContent -match "IngestionMode.*LogAnalytics"
        Write-TestResult "Application Insights Log Analytics integration" $hasWorkspaceIntegration "Log Analytics workspace integration configured"
    } catch {
        Write-TestResult "Application Insights Log Analytics integration" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 3: Validate availability tests configuration
    try {
        $templateContent = Get-Content "modules/monitoring/application-insights.bicep" -Raw
        $hasAvailabilityTests = $templateContent -match "Microsoft.Insights/webtests" -and $templateContent -match "availabilityTestUrls" -and $templateContent -match "SyntheticMonitorId"
        Write-TestResult "Application Insights availability tests" $hasAvailabilityTests "Availability tests properly configured"
    } catch {
        Write-TestResult "Application Insights availability tests" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 4: Validate data retention and sampling
    try {
        $templateContent = Get-Content "modules/monitoring/application-insights.bicep" -Raw
        $hasDataConfig = $templateContent -match "RetentionInDays" -and $templateContent -match "SamplingPercentage" -and $templateContent -match "dailyDataCapInGB"
        Write-TestResult "Application Insights data configuration" $hasDataConfig "Data retention and sampling properly configured"
    } catch {
        Write-TestResult "Application Insights data configuration" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 5: Validate custom metrics and analytics
    try {
        $templateContent = Get-Content "modules/monitoring/application-insights.bicep" -Raw
        $hasCustomMetrics = $templateContent -match "analyticsItems" -and $templateContent -match "customMetrics" -and $templateContent -match "errorRates"
        Write-TestResult "Application Insights custom metrics" $hasCustomMetrics "Custom metrics and analytics queries configured"
    } catch {
        Write-TestResult "Application Insights custom metrics" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 6: Validate security configuration
    try {
        $templateContent = Get-Content "modules/monitoring/application-insights.bicep" -Raw
        $hasSecurityConfig = $templateContent -match "DisableIpMasking.*false" -and $templateContent -match "DisableLocalAuth.*true" -and $templateContent -match "publicNetworkAccess"
        Write-TestResult "Application Insights security configuration" $hasSecurityConfig "Security settings properly configured"
    } catch {
        Write-TestResult "Application Insights security configuration" $false "Exception: $($_.Exception.Message)"
    }
}

function Test-AlertsModule {
    Write-Host "`nTesting Monitoring Alerts Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/monitoring/alerts.bicep" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Monitoring Alerts template syntax" $true
        } else {
            Write-TestResult "Monitoring Alerts template syntax" $false "Build failed: $buildResult"
        }
    } catch {
        Write-TestResult "Monitoring Alerts template syntax" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 2: Validate action groups configuration
    try {
        $templateContent = Get-Content "modules/monitoring/alerts.bicep" -Raw
        $hasActionGroups = $templateContent -match "Microsoft.Insights/actionGroups" -and $templateContent -match "emailReceivers" -and $templateContent -match "smsReceivers" -and $templateContent -match "webhookReceivers"
        Write-TestResult "Monitoring Alerts action groups" $hasActionGroups "Action groups with email, SMS, and webhook receivers configured"
    } catch {
        Write-TestResult "Monitoring Alerts action groups" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 3: Validate security alert rules
    try {
        $templateContent = Get-Content "modules/monitoring/alerts.bicep" -Raw
        $hasSecurityAlerts = $templateContent -match "security-failed-logins" -and $templateContent -match "security-privilege-escalation" -and $templateContent -match "EventID == 4625"
        Write-TestResult "Monitoring Alerts security rules" $hasSecurityAlerts "Security alert rules for failed logins and privilege escalation configured"
    } catch {
        Write-TestResult "Monitoring Alerts security rules" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 4: Validate performance alert rules
    try {
        $templateContent = Get-Content "modules/monitoring/alerts.bicep" -Raw
        $hasPerformanceAlerts = $templateContent -match "performance-high-cpu" -and $templateContent -match "performance-low-memory" -and $templateContent -match "performance-low-disk-space"
        Write-TestResult "Monitoring Alerts performance rules" $hasPerformanceAlerts "Performance alert rules for CPU, memory, and disk space configured"
    } catch {
        Write-TestResult "Monitoring Alerts performance rules" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 5: Validate availability alert rules
    try {
        $templateContent = Get-Content "modules/monitoring/alerts.bicep" -Raw
        $hasAvailabilityAlerts = $templateContent -match "availability-app-insights" -and $templateContent -match "availability-response-time" -and $templateContent -match "availabilityResults/availabilityPercentage"
        Write-TestResult "Monitoring Alerts availability rules" $hasAvailabilityAlerts "Availability alert rules for application insights and response time configured"
    } catch {
        Write-TestResult "Monitoring Alerts availability rules" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 6: Validate database-specific alerts
    try {
        $templateContent = Get-Content "modules/monitoring/alerts.bicep" -Raw
        $hasDatabaseAlerts = $templateContent -match "database-connection-failures" -and $templateContent -match "MICROSOFT.SQL" -and $templateContent -match "Category == \"Errors\""
        Write-TestResult "Monitoring Alerts database rules" $hasDatabaseAlerts "Database-specific alert rules configured"
    } catch {
        Write-TestResult "Monitoring Alerts database rules" $false "Exception: $($_.Exception.Message)"
    }
}

function Test-DiagnosticSettingsModule {
    Write-Host "`nTesting Diagnostic Settings Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/monitoring/diagnostic-settings.bicep" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Diagnostic Settings template syntax" $true
        } else {
            Write-TestResult "Diagnostic Settings template syntax" $false "Build failed: $buildResult"
        }
    } catch {
        Write-TestResult "Diagnostic Settings template syntax" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 2: Validate multiple destination support
    try {
        $templateContent = Get-Content "modules/monitoring/diagnostic-settings.bicep" -Raw
        $hasMultipleDestinations = $templateContent -match "logAnalyticsWorkspaceId" -and $templateContent -match "storageAccountId" -and $templateContent -match "eventHubAuthorizationRuleId"
        Write-TestResult "Diagnostic Settings multiple destinations" $hasMultipleDestinations "Support for Log Analytics, Storage Account, and Event Hub destinations"
    } catch {
        Write-TestResult "Diagnostic Settings multiple destinations" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 3: Validate resource type specific log categories
    try {
        $templateContent = Get-Content "modules/monitoring/diagnostic-settings.bicep" -Raw
        $hasResourceSpecificLogs = $templateContent -match "Microsoft.KeyVault/vaults" -and $templateContent -match "Microsoft.Storage/storageAccounts" -and $templateContent -match "Microsoft.Sql/servers/databases"
        Write-TestResult "Diagnostic Settings resource-specific logs" $hasResourceSpecificLogs "Resource-specific log categories configured for Key Vault, Storage, and SQL"
    } catch {
        Write-TestResult "Diagnostic Settings resource-specific logs" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 4: Validate retention policy configuration
    try {
        $templateContent = Get-Content "modules/monitoring/diagnostic-settings.bicep" -Raw
        $hasRetentionPolicies = $templateContent -match "retentionPolicy" -and $templateContent -match "logRetentionDays" -and $templateContent -match "metricRetentionDays"
        Write-TestResult "Diagnostic Settings retention policies" $hasRetentionPolicies "Retention policies for logs and metrics configured"
    } catch {
        Write-TestResult "Diagnostic Settings retention policies" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 5: Validate conditional deployment logic
    try {
        $templateContent = Get-Content "modules/monitoring/diagnostic-settings.bicep" -Raw
        $hasConditionalLogic = $templateContent -match "hasLogAnalytics" -and $templateContent -match "hasStorageAccount" -and $templateContent -match "hasEventHub" -and $templateContent -match "hasDestination"
        Write-TestResult "Diagnostic Settings conditional deployment" $hasConditionalLogic "Conditional deployment logic for different destination types"
    } catch {
        Write-TestResult "Diagnostic Settings conditional deployment" $false "Exception: $($_.Exception.Message)"
    }
}

function Test-MonitoringIntegration {
    Write-Host "`nTesting Monitoring Integration..." -ForegroundColor Cyan
    
    # Test 1: Validate main template integration
    try {
        $mainTemplateContent = Get-Content "main.bicep" -Raw
        $hasMonitoringIntegration = $mainTemplateContent -match "modules/monitoring/log-analytics.bicep" -and $mainTemplateContent -match "modules/monitoring/application-insights.bicep" -and $mainTemplateContent -match "modules/monitoring/alerts.bicep"
        Write-TestResult "Main template monitoring integration" $hasMonitoringIntegration "Monitoring modules integrated into main template"
    } catch {
        Write-TestResult "Main template monitoring integration" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 2: Validate monitoring outputs
    try {
        $mainTemplateContent = Get-Content "main.bicep" -Raw
        $hasMonitoringOutputs = $mainTemplateContent -match "output monitoring object" -and $mainTemplateContent -match "logAnalyticsWorkspace:" -and $mainTemplateContent -match "applicationInsights:" -and $mainTemplateContent -match "alerts:"
        Write-TestResult "Main template monitoring outputs" $hasMonitoringOutputs "Monitoring outputs properly configured in main template"
    } catch {
        Write-TestResult "Main template monitoring outputs" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 3: Validate diagnostic settings deployment
    try {
        $mainTemplateContent = Get-Content "main.bicep" -Raw
        $hasDiagnosticSettings = $mainTemplateContent -match "modules/monitoring/diagnostic-settings.bicep" -and $mainTemplateContent -match "key-vault-diagnostics" -and $mainTemplateContent -match "application-gateway-diagnostics"
        Write-TestResult "Main template diagnostic settings" $hasDiagnosticSettings "Diagnostic settings deployed for key resources"
    } catch {
        Write-TestResult "Main template diagnostic settings" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 4: Validate parameter file configurations
    try {
        $devParamsExist = Test-Path "parameters/dev.parameters.json"
        $stagingParamsExist = Test-Path "parameters/staging.parameters.json"
        $prodParamsExist = Test-Path "parameters/prod.parameters.json"
        
        $allParamsExist = $devParamsExist -and $stagingParamsExist -and $prodParamsExist
        Write-TestResult "Monitoring parameter files" $allParamsExist "Environment-specific parameter files exist for monitoring configuration"
    } catch {
        Write-TestResult "Monitoring parameter files" $false "Exception: $($_.Exception.Message)"
    }
}

# Main execution logic
Write-Host "Starting Monitoring Modules Unit Tests..." -ForegroundColor Yellow
Write-Host "Test Scope: $TestScope" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host ""

# Execute tests based on scope
switch ($TestScope.ToLower()) {
    "loganalytics" {
        Test-LogAnalyticsModule
    }
    "applicationinsights" {
        Test-ApplicationInsightsModule
    }
    "alerts" {
        Test-AlertsModule
    }
    "diagnosticsettings" {
        Test-DiagnosticSettingsModule
    }
    "integration" {
        Test-MonitoringIntegration
    }
    "all" {
        Test-LogAnalyticsModule
        Test-ApplicationInsightsModule
        Test-AlertsModule
        Test-DiagnosticSettingsModule
        Test-MonitoringIntegration
    }
    default {
        Write-Host "Invalid test scope. Valid options: LogAnalytics, ApplicationInsights, Alerts, DiagnosticSettings, Integration, All" -ForegroundColor Red
        exit 1
    }
}

# Generate test summary
Write-Host "`n" + "="*50 -ForegroundColor Yellow
Write-Host "Test Summary" -ForegroundColor Yellow
Write-Host "="*50 -ForegroundColor Yellow

$totalTests = $testResults.Count
$passedTests = ($testResults | Where-Object { $_.Passed }).Count
$failedTests = $totalTests - $passedTests

Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor Red

if ($failedTests -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $testResults | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.TestName): $($_.Message)" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    exit 0
}