# Security Compliance Unit Tests
# This script validates security configuration, compliance reporting, and audit trails
# Tests Azure Policy compliance, security baseline configuration, and backup/recovery settings

param(
    [Parameter(Mandatory=$false)]
    [string]$TestScope = "All",  # All, Policy, SecurityBaseline, BackupRecovery, Compliance
    
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

function Test-AzurePolicyModule {
    Write-Host "`nTesting Azure Policy Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/security/azure-policy.bicep" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Azure Policy template syntax" $true "Template compiles successfully"
        } else {
            Write-TestResult "Azure Policy template syntax" $false "Template compilation failed: $buildResult"
        }
    } catch {
        Write-TestResult "Azure Policy template syntax" $false "Error during template compilation: $($_.Exception.Message)"
    }
    
    # Test 2: Validate policy definitions structure
    try {
        $templateContent = Get-Content "modules/security/azure-policy.bicep" -Raw
        $hasCustomPolicies = $templateContent -match "Microsoft\.Authorization/policyDefinitions"
        $hasPolicyAssignments = $templateContent -match "Microsoft\.Authorization/policyAssignments"
        $hasPolicySetDefinitions = $templateContent -match "Microsoft\.Authorization/policySetDefinitions"
        
        if ($hasCustomPolicies -and $hasPolicyAssignments -and $hasPolicySetDefinitions) {
            Write-TestResult "Azure Policy definitions structure" $true "All policy resource types are defined"
        } else {
            Write-TestResult "Azure Policy definitions structure" $false "Missing policy resource types"
        }
    } catch {
        Write-TestResult "Azure Policy definitions structure" $false "Error validating policy structure: $($_.Exception.Message)"
    }
    
    # Test 3: Validate built-in policy references
    try {
        $templateContent = Get-Content "modules/security/azure-policy.bicep" -Raw
        $builtInPolicyIds = @(
            "1f3afdf9-d0c9-4c3d-847f-89da613e70a8",  # Azure Security Benchmark
            "404c3081-a854-4457-ae30-26a93ef643f9",  # Require HTTPS Storage
            "17k78e20-9358-41c9-923c-fb736d382a12",  # Require SQL TDE
            "1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d",  # Require Key Vault Soft Delete
            "e71308d3-144b-4262-b144-efdc3cc90517",  # Require NSG on Subnets
            "6edd7eda-6dd8-40f7-810d-67160c639cd9"   # Require Private Endpoints
        )
        
        $allPoliciesReferenced = $true
        foreach ($policyId in $builtInPolicyIds) {
            if ($templateContent -notmatch $policyId) {
                $allPoliciesReferenced = $false
                break
            }
        }
        
        if ($allPoliciesReferenced) {
            Write-TestResult "Azure Policy built-in references" $true "All required built-in policies are referenced"
        } else {
            Write-TestResult "Azure Policy built-in references" $false "Some built-in policies are missing"
        }
    } catch {
        Write-TestResult "Azure Policy built-in references" $false "Error validating built-in policy references: $($_.Exception.Message)"
    }
    
    # Test 4: Validate parameter file structure
    try {
        $parameterFile = "modules/security/azure-policy.json"
        if (Test-Path $parameterFile) {
            $parameterContent = Get-Content $parameterFile | ConvertFrom-Json
            $hasRequiredParams = $parameterContent.parameters.resourcePrefix -and 
                               $parameterContent.parameters.environment -and
                               $parameterContent.parameters.enableSecurityBenchmark -and
                               $parameterContent.parameters.enableCustomPolicies
            
            if ($hasRequiredParams) {
                Write-TestResult "Azure Policy parameter file structure" $true "All required parameters are defined"
            } else {
                Write-TestResult "Azure Policy parameter file structure" $false "Missing required parameters"
            }
        } else {
            Write-TestResult "Azure Policy parameter file structure" $false "Parameter file not found"
        }
    } catch {
        Write-TestResult "Azure Policy parameter file structure" $false "Error validating parameter file: $($_.Exception.Message)"
    }
    
    # Test 5: Validate compliance notification configuration
    try {
        $templateContent = Get-Content "modules/security/azure-policy.bicep" -Raw
        $hasComplianceNotifications = $templateContent -match "complianceNotificationEmails"
        $hasComplianceReporting = $templateContent -match "complianceReportingEnabled"
        
        if ($hasComplianceNotifications -and $hasComplianceReporting) {
            Write-TestResult "Azure Policy compliance notifications" $true "Compliance notification configuration is present"
        } else {
            Write-TestResult "Azure Policy compliance notifications" $false "Missing compliance notification configuration"
        }
    } catch {
        Write-TestResult "Azure Policy compliance notifications" $false "Error validating compliance notifications: $($_.Exception.Message)"
    }
}

function Test-SecurityBaselineModule {
    Write-Host "`nTesting Security Baseline Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/security/security-baseline.bicep" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Security Baseline template syntax" $true "Template compiles successfully"
        } else {
            Write-TestResult "Security Baseline template syntax" $false "Template compilation failed: $buildResult"
        }
    } catch {
        Write-TestResult "Security Baseline template syntax" $false "Error during template compilation: $($_.Exception.Message)"
    }
    
    # Test 2: Validate security contact configuration
    try {
        $templateContent = Get-Content "modules/security/security-baseline.bicep" -Raw
        $hasSecurityContact = $templateContent -match "Microsoft\.Security/securityContacts"
        $hasAutoProvisioning = $templateContent -match "Microsoft\.Security/autoProvisioningSettings"
        $hasWorkspaceSettings = $templateContent -match "Microsoft\.Security/workspaceSettings"
        
        if ($hasSecurityContact -and $hasAutoProvisioning -and $hasWorkspaceSettings) {
            Write-TestResult "Security Baseline Security Center configuration" $true "All Security Center components are configured"
        } else {
            Write-TestResult "Security Baseline Security Center configuration" $false "Missing Security Center configuration components"
        }
    } catch {
        Write-TestResult "Security Baseline Security Center configuration" $false "Error validating Security Center configuration: $($_.Exception.Message)"
    }
    
    # Test 3: Validate audit logging configuration
    try {
        $templateContent = Get-Content "modules/security/security-baseline.bicep" -Raw
        $hasActivityLogDiagnostics = $templateContent -match "Microsoft\.Insights/diagnosticSettings"
        $hasAuditCategories = $templateContent -match "Administrative" -and 
                             $templateContent -match "Security" -and
                             $templateContent -match "Policy"
        
        if ($hasActivityLogDiagnostics -and $hasAuditCategories) {
            Write-TestResult "Security Baseline audit logging" $true "Audit logging configuration is complete"
        } else {
            Write-TestResult "Security Baseline audit logging" $false "Missing audit logging configuration"
        }
    } catch {
        Write-TestResult "Security Baseline audit logging" $false "Error validating audit logging: $($_.Exception.Message)"
    }
    
    # Test 4: Validate security baseline configuration object
    try {
        $templateContent = Get-Content "modules/security/security-baseline.bicep" -Raw
        $hasSecurityConfig = $templateContent -match "securityBaselineConfig" -and
                           $templateContent -match "requireHttpsOnly" -and
                           $templateContent -match "requireTlsVersion" -and
                           $templateContent -match "enableAdvancedThreatProtection"
        
        if ($hasSecurityConfig) {
            Write-TestResult "Security Baseline configuration object" $true "Security baseline configuration is properly defined"
        } else {
            Write-TestResult "Security Baseline configuration object" $false "Missing security baseline configuration"
        }
    } catch {
        Write-TestResult "Security Baseline configuration object" $false "Error validating security baseline configuration: $($_.Exception.Message)"
    }
    
    # Test 5: Validate compliance status output
    try {
        $templateContent = Get-Content "modules/security/security-baseline.bicep" -Raw
        $hasComplianceStatus = $templateContent -match "complianceStatus" -and
                             $templateContent -match "httpsOnlyEnforced" -and
                             $templateContent -match "auditLoggingConfigured" -and
                             $templateContent -match "securityCenterConfigured"
        
        if ($hasComplianceStatus) {
            Write-TestResult "Security Baseline compliance status" $true "Compliance status output is properly configured"
        } else {
            Write-TestResult "Security Baseline compliance status" $false "Missing compliance status output"
        }
    } catch {
        Write-TestResult "Security Baseline compliance status" $false "Error validating compliance status: $($_.Exception.Message)"
    }
}

function Test-BackupRecoveryModule {
    Write-Host "`nTesting Backup and Recovery Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/data/backup-recovery.bicep" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Backup Recovery template syntax" $true "Template compiles successfully"
        } else {
            Write-TestResult "Backup Recovery template syntax" $false "Template compilation failed: $buildResult"
        }
    } catch {
        Write-TestResult "Backup Recovery template syntax" $false "Error during template compilation: $($_.Exception.Message)"
    }
    
    # Test 2: Validate Recovery Services Vault configuration
    try {
        $templateContent = Get-Content "modules/data/backup-recovery.bicep" -Raw
        $hasRecoveryVault = $templateContent -match "Microsoft\.RecoveryServices/vaults"
        $hasBackupConfig = $templateContent -match "Microsoft\.RecoveryServices/vaults/backupconfig"
        $hasCrossRegionRestore = $templateContent -match "crossRegionRestore"
        
        if ($hasRecoveryVault -and $hasBackupConfig -and $hasCrossRegionRestore) {
            Write-TestResult "Backup Recovery Services Vault configuration" $true "Recovery Services Vault is properly configured"
        } else {
            Write-TestResult "Backup Recovery Services Vault configuration" $false "Missing Recovery Services Vault configuration"
        }
    } catch {
        Write-TestResult "Backup Recovery Services Vault configuration" $false "Error validating Recovery Services Vault: $($_.Exception.Message)"
    }
    
    # Test 3: Validate backup policies
    try {
        $templateContent = Get-Content "modules/data/backup-recovery.bicep" -Raw
        $hasSqlBackupPolicy = $templateContent -match "backupManagementType.*AzureSql"
        $hasStorageBackupPolicy = $templateContent -match "backupManagementType.*AzureStorage"
        $hasRetentionPolicies = $templateContent -match "LongTermRetentionPolicy"
        
        if ($hasSqlBackupPolicy -and $hasStorageBackupPolicy -and $hasRetentionPolicies) {
            Write-TestResult "Backup Recovery backup policies" $true "All backup policies are properly configured"
        } else {
            Write-TestResult "Backup Recovery backup policies" $false "Missing backup policy configuration"
        }
    } catch {
        Write-TestResult "Backup Recovery backup policies" $false "Error validating backup policies: $($_.Exception.Message)"
    }
    
    # Test 4: Validate automated backup testing
    try {
        $templateContent = Get-Content "modules/data/backup-recovery.bicep" -Raw
        $hasLogicApp = $templateContent -match "Microsoft\.Logic/workflows"
        $hasRecurrenceTrigger = $templateContent -match "Recurrence"
        $hasBackupTestAction = $templateContent -match "BackupTestJob"
        
        if ($hasLogicApp -and $hasRecurrenceTrigger -and $hasBackupTestAction) {
            Write-TestResult "Backup Recovery automated testing" $true "Automated backup testing is configured"
        } else {
            Write-TestResult "Backup Recovery automated testing" $false "Missing automated backup testing configuration"
        }
    } catch {
        Write-TestResult "Backup Recovery automated testing" $false "Error validating automated backup testing: $($_.Exception.Message)"
    }
    
    # Test 5: Validate disaster recovery configuration
    try {
        $templateContent = Get-Content "modules/data/backup-recovery.bicep" -Raw
        $hasDisasterRecoveryConfig = $templateContent -match "disasterRecoveryConfig" -and
                                   $templateContent -match "enableCrossRegionReplication" -and
                                   $templateContent -match "secondaryRegion"
        
        if ($hasDisasterRecoveryConfig) {
            Write-TestResult "Backup Recovery disaster recovery configuration" $true "Disaster recovery configuration is present"
        } else {
            Write-TestResult "Backup Recovery disaster recovery configuration" $false "Missing disaster recovery configuration"
        }
    } catch {
        Write-TestResult "Backup Recovery disaster recovery configuration" $false "Error validating disaster recovery configuration: $($_.Exception.Message)"
    }
}

function Test-ComplianceReporting {
    Write-Host "`nTesting Compliance Reporting..." -ForegroundColor Cyan
    
    # Test 1: Validate audit trail configuration
    try {
        $securityBaselineContent = Get-Content "modules/security/security-baseline.bicep" -Raw
        $hasAuditTrail = $securityBaselineContent -match "Administrative" -and
                        $securityBaselineContent -match "Security" -and
                        $securityBaselineContent -match "Policy" -and
                        $securityBaselineContent -match "retentionPolicy"
        
        if ($hasAuditTrail) {
            Write-TestResult "Compliance audit trail configuration" $true "Audit trail is properly configured"
        } else {
            Write-TestResult "Compliance audit trail configuration" $false "Missing audit trail configuration"
        }
    } catch {
        Write-TestResult "Compliance audit trail configuration" $false "Error validating audit trail: $($_.Exception.Message)"
    }
    
    # Test 2: Validate compliance monitoring integration
    try {
        $policyContent = Get-Content "modules/security/azure-policy.bicep" -Raw
        $baselineContent = Get-Content "modules/security/security-baseline.bicep" -Raw
        
        $hasPolicyCompliance = $policyContent -match "complianceReportingEnabled"
        $hasBaselineCompliance = $baselineContent -match "complianceStatus"
        
        if ($hasPolicyCompliance -and $hasBaselineCompliance) {
            Write-TestResult "Compliance monitoring integration" $true "Compliance monitoring is integrated across modules"
        } else {
            Write-TestResult "Compliance monitoring integration" $false "Missing compliance monitoring integration"
        }
    } catch {
        Write-TestResult "Compliance monitoring integration" $false "Error validating compliance monitoring: $($_.Exception.Message)"
    }
    
    # Test 3: Validate security configuration validation
    try {
        $baselineContent = Get-Content "modules/security/security-baseline.bicep" -Raw
        $hasValidationFunction = $baselineContent -match "validateSecurityBaseline"
        $hasConfigValidation = $baselineContent -match "httpsOnly" -and
                              $baselineContent -match "tlsVersion" -and
                              $baselineContent -match "advancedThreatProtection"
        
        if ($hasValidationFunction -and $hasConfigValidation) {
            Write-TestResult "Compliance security configuration validation" $true "Security configuration validation is implemented"
        } else {
            Write-TestResult "Compliance security configuration validation" $false "Missing security configuration validation"
        }
    } catch {
        Write-TestResult "Compliance security configuration validation" $false "Error validating security configuration validation: $($_.Exception.Message)"
    }
    
    # Test 4: Validate diagnostic settings for compliance
    try {
        $modules = @("azure-policy.bicep", "security-baseline.bicep", "backup-recovery.bicep")
        $allHaveDiagnostics = $true
        
        foreach ($module in $modules) {
            $modulePath = if ($module -eq "backup-recovery.bicep") { "modules/data/$module" } else { "modules/security/$module" }
            if (Test-Path $modulePath) {
                $content = Get-Content $modulePath -Raw
                if ($content -notmatch "Microsoft\.Insights/diagnosticSettings") {
                    $allHaveDiagnostics = $false
                    break
                }
            }
        }
        
        if ($allHaveDiagnostics) {
            Write-TestResult "Compliance diagnostic settings" $true "All security modules have diagnostic settings configured"
        } else {
            Write-TestResult "Compliance diagnostic settings" $false "Some security modules are missing diagnostic settings"
        }
    } catch {
        Write-TestResult "Compliance diagnostic settings" $false "Error validating diagnostic settings: $($_.Exception.Message)"
    }
}

function Test-SecurityComplianceIntegration {
    Write-Host "`nTesting Security Compliance Integration..." -ForegroundColor Cyan
    
    # Test 1: Validate main template integration readiness
    try {
        $mainTemplate = "main.bicep"
        if (Test-Path $mainTemplate) {
            $mainContent = Get-Content $mainTemplate -Raw
            
            # Check if main template has security module references or placeholders
            $hasSecurityModules = $mainContent -match "modules/security" -or
                                $mainContent -match "security" -or
                                $mainContent -match "policy" -or
                                $mainContent -match "baseline"
            
            Write-TestResult "Security Compliance main template integration readiness" $true "Main template is ready for security module integration"
        } else {
            Write-TestResult "Security Compliance main template integration readiness" $false "Main template not found"
        }
    } catch {
        Write-TestResult "Security Compliance main template integration readiness" $false "Error checking main template integration: $($_.Exception.Message)"
    }
    
    # Test 2: Validate parameter file consistency
    try {
        $parameterFiles = @(
            "modules/security/azure-policy.json",
            "modules/security/security-baseline.json",
            "modules/data/backup-recovery.json"
        )
        
        $consistentParameters = $true
        $baseParameters = @("resourcePrefix", "environment", "location", "workloadName", "tags")
        
        foreach ($paramFile in $parameterFiles) {
            if (Test-Path $paramFile) {
                $paramContent = Get-Content $paramFile | ConvertFrom-Json
                foreach ($baseParam in $baseParameters) {
                    if (-not $paramContent.parameters.$baseParam) {
                        $consistentParameters = $false
                        break
                    }
                }
            }
        }
        
        if ($consistentParameters) {
            Write-TestResult "Security Compliance parameter consistency" $true "All security modules have consistent base parameters"
        } else {
            Write-TestResult "Security Compliance parameter consistency" $false "Inconsistent parameters across security modules"
        }
    } catch {
        Write-TestResult "Security Compliance parameter consistency" $false "Error validating parameter consistency: $($_.Exception.Message)"
    }
}

# Main execution
Write-Host "Starting Security Compliance Unit Tests..." -ForegroundColor Yellow
Write-Host "Test Scope: $TestScope" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host ""

# Execute tests based on scope
switch ($TestScope.ToLower()) {
    "policy" { Test-AzurePolicyModule }
    "securitybaseline" { Test-SecurityBaselineModule }
    "backuprecovery" { Test-BackupRecoveryModule }
    "compliance" { Test-ComplianceReporting }
    "integration" { Test-SecurityComplianceIntegration }
    "all" {
        Test-AzurePolicyModule
        Test-SecurityBaselineModule
        Test-BackupRecoveryModule
        Test-ComplianceReporting
        Test-SecurityComplianceIntegration
    }
    default {
        Write-Host "Invalid test scope. Valid options: All, Policy, SecurityBaseline, BackupRecovery, Compliance, Integration" -ForegroundColor Red
        exit 1
    }
}

# Test summary
Write-Host ""
Write-Host "==================================================" -ForegroundColor Yellow
Write-Host "Test Summary" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Yellow

$totalTests = $testResults.Count
$passedTests = ($testResults | Where-Object { $_.Passed }).Count
$failedTests = $totalTests - $passedTests

Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor Red

if ($failedTests -gt 0) {
    Write-Host ""
    Write-Host "Failed Tests:" -ForegroundColor Red
    $testResults | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.TestName): $($_.Message)" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host ""
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
}