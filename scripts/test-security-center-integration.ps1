#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for Security Center module integration validation
.DESCRIPTION
    This script validates the Security Center module integration with the main template
    and ensures all components are properly configured.
.PARAMETER Environment
    The environment to test (dev, staging, prod)
.PARAMETER VerboseOutput
    Enable verbose output for detailed test results
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Test configuration
$TestResults = @()
$TestsPassed = 0
$TestsFailed = 0

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    $Result = [PSCustomObject]@{
        TestName = $TestName
        Passed = $Passed
        Details = $Details
        Timestamp = Get-Date
    }
    
    $script:TestResults += $Result
    
    if ($Passed) {
        $script:TestsPassed++
        Write-Host "✓ $TestName" -ForegroundColor Green
    } else {
        $script:TestsFailed++
        Write-Host "✗ $TestName" -ForegroundColor Red
        if ($Details) {
            Write-Host "  Details: $Details" -ForegroundColor Yellow
        }
    }
    
    if ($VerboseOutput -and $Details) {
        Write-Host "  $Details" -ForegroundColor Gray
    }
}

function Test-SecurityCenterModule {
    Write-Host "`nTesting Security Center Module..." -ForegroundColor Cyan
    
    # Test 1: Security Center module syntax validation
    try {
        $buildResult = az bicep build --file "modules/security/security-center.bicep" 2>&1
        $syntaxValid = $LASTEXITCODE -eq 0
        Write-TestResult "Security Center module syntax validation" $syntaxValid "Bicep compilation completed"
    } catch {
        Write-TestResult "Security Center module syntax validation" $false "Compilation failed: $($_.Exception.Message)"
    }
    
    # Test 2: Main template integration validation
    try {
        $buildResult = az bicep build --file "main.bicep" 2>&1
        $integrationValid = $LASTEXITCODE -eq 0
        Write-TestResult "Main template integration validation" $integrationValid "Main template compiles with Security Center integration"
    } catch {
        Write-TestResult "Main template integration validation" $false "Main template compilation failed: $($_.Exception.Message)"
    }
    
    # Test 3: Parameter file compatibility
    try {
        $paramFile = "parameters/$Environment.parameters.json"
        if (Test-Path $paramFile) {
            $params = Get-Content $paramFile | ConvertFrom-Json
            $hasRequiredParams = $params.parameters.resourcePrefix -and $params.parameters.environment -and $params.parameters.environmentConfig
            Write-TestResult "Parameter file compatibility" $hasRequiredParams "Parameter file contains required parameters for Security Center"
        } else {
            Write-TestResult "Parameter file compatibility" $false "Parameter file not found: $paramFile"
        }
    } catch {
        Write-TestResult "Parameter file compatibility" $false "Parameter validation failed: $($_.Exception.Message)"
    }
}

function Test-SecurityCenterConfiguration {
    Write-Host "`nTesting Security Center Configuration..." -ForegroundColor Cyan
    
    # Test 4: Defender plans configuration
    try {
        $securityCenterContent = Get-Content "modules/security/security-center.bicep" -Raw
        $hasDefenderPlans = $securityCenterContent -match "defenderPlans.*array"
        $hasRequiredPlans = $securityCenterContent -match "VirtualMachines" -and 
                           $securityCenterContent -match "SqlServers" -and 
                           $securityCenterContent -match "StorageAccounts" -and 
                           $securityCenterContent -match "KeyVaults"
        Write-TestResult "Defender plans configuration" ($hasDefenderPlans -and $hasRequiredPlans) "All required Defender plans are configured"
    } catch {
        Write-TestResult "Defender plans configuration" $false "Configuration validation failed: $($_.Exception.Message)"
    }
    
    # Test 5: Security contacts configuration
    try {
        $hasSecurityContacts = $securityCenterContent -match "securityContacts.*array"
        $hasContactProperties = $securityCenterContent -match "email" -and $securityCenterContent -match "phone" -and $securityCenterContent -match "alertNotifications"
        Write-TestResult "Security contacts configuration" ($hasSecurityContacts -and $hasContactProperties) "Security contacts are properly configured"
    } catch {
        Write-TestResult "Security contacts configuration" $false "Security contacts validation failed: $($_.Exception.Message)"
    }
    
    # Test 6: Auto provisioning settings
    try {
        $hasAutoProvisioning = $securityCenterContent -match "autoProvisioningSettings.*object"
        $hasLogAnalyticsIntegration = $securityCenterContent -match "logAnalytics.*On"
        Write-TestResult "Auto provisioning configuration" ($hasAutoProvisioning -and $hasLogAnalyticsIntegration) "Auto provisioning is configured with Log Analytics integration"
    } catch {
        Write-TestResult "Auto provisioning configuration" $false "Auto provisioning validation failed: $($_.Exception.Message)"
    }
}

function Test-MonitoringAlertsIntegration {
    Write-Host "`nTesting Monitoring Alerts Integration..." -ForegroundColor Cyan
    
    # Test 7: Security Center alerts in monitoring module
    try {
        $alertsContent = Get-Content "modules/monitoring/alerts.bicep" -Raw
        $hasSecurityCenterAlerts = $alertsContent -match "securityCenterHighSeverityAlert" -and 
                                  $alertsContent -match "securityCenterThreatDetectionAlert" -and 
                                  $alertsContent -match "securityCenterComplianceAlert" -and 
                                  $alertsContent -match "securityCenterVulnerabilityAlert"
        Write-TestResult "Security Center alerts integration" $hasSecurityCenterAlerts "Security Center-specific alerts are integrated in monitoring module"
    } catch {
        Write-TestResult "Security Center alerts integration" $false "Alerts integration validation failed: $($_.Exception.Message)"
    }
    
    # Test 8: Alert queries validation
    try {
        $hasSecurityRecommendationQuery = $alertsContent -match "SecurityRecommendation.*RecommendationSeverity"
        $hasSecurityAlertQuery = $alertsContent -match "SecurityAlert.*AlertSeverity"
        Write-TestResult "Security Center alert queries" ($hasSecurityRecommendationQuery -and $hasSecurityAlertQuery) "Security Center alert queries are properly configured"
    } catch {
        Write-TestResult "Security Center alert queries" $false "Alert queries validation failed: $($_.Exception.Message)"
    }
}

function Test-MainTemplateIntegration {
    Write-Host "`nTesting Main Template Integration..." -ForegroundColor Cyan
    
    # Test 9: Security Center module deployment in main template
    try {
        $mainContent = Get-Content "main.bicep" -Raw
        $hasSecurityCenterModule = $mainContent -match "module securityCenter.*security-center.bicep"
        $hasSubscriptionScope = $mainContent -match "scope: subscription\(\)"
        Write-TestResult "Security Center module deployment" ($hasSecurityCenterModule -and $hasSubscriptionScope) "Security Center module is properly deployed with subscription scope"
    } catch {
        Write-TestResult "Security Center module deployment" $false "Main template integration validation failed: $($_.Exception.Message)"
    }
    
    # Test 10: Security Center outputs
    try {
        $hasSecurityCenterOutputs = $mainContent -match "securityCenter:" -and 
                                   $mainContent -match "defenderPlansConfig" -and 
                                   $mainContent -match "securityContactsConfig" -and 
                                   $mainContent -match "securityCenterConfig"
        Write-TestResult "Security Center outputs" $hasSecurityCenterOutputs "Security Center outputs are properly configured in main template"
    } catch {
        Write-TestResult "Security Center outputs" $false "Security Center outputs validation failed: $($_.Exception.Message)"
    }
}

# Main execution
Write-Host "Starting Security Center Integration Tests..." -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Gray
Write-Host "Verbose Output: $($VerboseOutput.IsPresent)" -ForegroundColor Gray
Write-Host ""

# Run all tests
Test-SecurityCenterModule
Test-SecurityCenterConfiguration
Test-MonitoringAlertsIntegration
Test-MainTemplateIntegration

# Display summary
Write-Host "`n" + "="*50 -ForegroundColor Yellow
Write-Host "Test Summary" -ForegroundColor Yellow
Write-Host "="*50 -ForegroundColor Yellow
Write-Host "Total Tests: $($TestsPassed + $TestsFailed)" -ForegroundColor White
Write-Host "Passed: $TestsPassed" -ForegroundColor Green
Write-Host "Failed: $TestsFailed" -ForegroundColor Red

if ($TestsFailed -eq 0) {
    Write-Host "`nAll tests passed! Security Center integration is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed. Please review the results above." -ForegroundColor Red
    
    if ($VerboseOutput) {
        Write-Host "`nDetailed Test Results:" -ForegroundColor Yellow
        $TestResults | Where-Object { -not $_.Passed } | ForEach-Object {
            Write-Host "- $($_.TestName): $($_.Details)" -ForegroundColor Red
        }
    }
    
    exit 1
}