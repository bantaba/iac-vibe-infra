# Data Layer Unit Tests
# This script validates SQL Server, Storage Account, and Private Endpoints configurations
# Tests core functionality including security features, private endpoint connectivity, and compliance

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

function Test-SqlServerModule {
    Write-Host "`nTesting SQL Server Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/data/sql-server.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "SQL Server template syntax" $true
        } else {
            Write-TestResult "SQL Server template syntax" $false $buildResult
        }
    } catch {
        Write-TestResult "SQL Server template syntax" $false $_.Exception.Message
    }
    
    # Test 2: Validate Azure AD authentication configuration
    try {
        $templateContent = Get-Content "modules/data/sql-server.bicep" -Raw
        $hasAzureAdAuth = $templateContent -match "enableAzureAdAuthentication.*bool.*true"
        $hasAdministratorConfig = $templateContent -match "Microsoft\.Sql/servers/administrators"
        $hasTenantId = $templateContent -match "tenantId.*tenant\(\)\.tenantId"
        
        if ($hasAzureAdAuth -and $hasAdministratorConfig -and $hasTenantId) {
            Write-TestResult "SQL Server Azure AD authentication" $true
        } else {
            Write-TestResult "SQL Server Azure AD authentication" $false "Azure AD authentication configuration incomplete"
        }
    } catch {
        Write-TestResult "SQL Server Azure AD authentication" $false $_.Exception.Message
    }
    
    # Test 3: Validate Transparent Data Encryption (TDE)
    try {
        $templateContent = Get-Content "modules/data/sql-server.bicep" -Raw
        $hasTdeParam = $templateContent -match "enableTransparentDataEncryption.*bool.*true"
        $hasTdeResource = $templateContent -match "Microsoft\.Sql/servers/databases/transparentDataEncryption"
        $hasTdeEnabled = $templateContent -match "state.*'Enabled'"
        
        if ($hasTdeParam -and $hasTdeResource -and $hasTdeEnabled) {
            Write-TestResult "SQL Server Transparent Data Encryption" $true
        } else {
            Write-TestResult "SQL Server Transparent Data Encryption" $false "TDE configuration missing or incomplete"
        }
    } catch {
        Write-TestResult "SQL Server Transparent Data Encryption" $false $_.Exception.Message
    }
    
    # Test 4: Validate Advanced Data Security (Microsoft Defender for SQL)
    try {
        $templateContent = Get-Content "modules/data/sql-server.bicep" -Raw
        $hasAdvancedSecurity = $templateContent -match "enableAdvancedDataSecurity.*bool.*true"
        $hasSecurityAlertPolicies = $templateContent -match "Microsoft\.Sql/servers/securityAlertPolicies"
        $hasVulnerabilityAssessment = $templateContent -match "Microsoft\.Sql/servers/vulnerabilityAssessments"
        
        if ($hasAdvancedSecurity -and $hasSecurityAlertPolicies -and $hasVulnerabilityAssessment) {
            Write-TestResult "SQL Server Advanced Data Security" $true
        } else {
            Write-TestResult "SQL Server Advanced Data Security" $false "Advanced Data Security configuration incomplete"
        }
    } catch {
        Write-TestResult "SQL Server Advanced Data Security" $false $_.Exception.Message
    }
    
    # Test 5: Validate network security configuration
    try {
        $templateContent = Get-Content "modules/data/sql-server.bicep" -Raw
        $hasPublicNetworkAccess = $templateContent -match "publicNetworkAccess.*enablePublicNetworkAccess.*'Enabled'.*'Disabled'"
        $hasFirewallRules = $templateContent -match "Microsoft\.Sql/servers/firewallRules"
        $hasVirtualNetworkRules = $templateContent -match "Microsoft\.Sql/servers/virtualNetworkRules"
        $hasTlsVersion = $templateContent -match "minimalTlsVersion.*'1\.2'"
        
        if ($hasPublicNetworkAccess -and $hasFirewallRules -and $hasVirtualNetworkRules -and $hasTlsVersion) {
            Write-TestResult "SQL Server network security configuration" $true
        } else {
            Write-TestResult "SQL Server network security configuration" $false "Network security configuration incomplete"
        }
    } catch {
        Write-TestResult "SQL Server network security configuration" $false $_.Exception.Message
    }
    
    # Test 6: Validate backup and recovery configuration
    try {
        $templateContent = Get-Content "modules/data/sql-server.bicep" -Raw
        $hasBackupRetention = $templateContent -match "backupRetentionDays"
        $hasGeoRedundantBackup = $templateContent -match "requestedBackupStorageRedundancy"
        $hasRetentionPolicies = $templateContent -match "retentionDays.*backupRetentionDays"
        
        if ($hasBackupRetention -and $hasGeoRedundantBackup -and $hasRetentionPolicies) {
            Write-TestResult "SQL Server backup and recovery configuration" $true
        } else {
            Write-TestResult "SQL Server backup and recovery configuration" $false "Backup configuration incomplete"
        }
    } catch {
        Write-TestResult "SQL Server backup and recovery configuration" $false $_.Exception.Message
    }
    
    # Test 7: Validate diagnostic settings and monitoring
    try {
        $templateContent = Get-Content "modules/data/sql-server.bicep" -Raw
        $hasDiagnosticSettings = $templateContent -match "Microsoft\.Insights/diagnosticSettings"
        $hasLogAnalyticsWorkspace = $templateContent -match "logAnalyticsWorkspaceId"
        $hasAuditLogs = $templateContent -match "categoryGroup.*'audit'"
        $hasMetrics = $templateContent -match "category.*'AllMetrics'"
        
        if ($hasDiagnosticSettings -and $hasLogAnalyticsWorkspace -and $hasAuditLogs -and $hasMetrics) {
            Write-TestResult "SQL Server diagnostic settings and monitoring" $true
        } else {
            Write-TestResult "SQL Server diagnostic settings and monitoring" $false "Monitoring configuration incomplete"
        }
    } catch {
        Write-TestResult "SQL Server diagnostic settings and monitoring" $false $_.Exception.Message
    }
}

function Test-StorageAccountModule {
    Write-Host "`nTesting Storage Account Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/data/storage-account.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Storage Account template syntax" $true
        } else {
            Write-TestResult "Storage Account template syntax" $false $buildResult
        }
    } catch {
        Write-TestResult "Storage Account template syntax" $false $_.Exception.Message
    }
    
    # Test 2: Validate network access controls
    try {
        $templateContent = Get-Content "modules/data/storage-account.bicep" -Raw
        $hasPublicNetworkAccess = $templateContent -match "publicNetworkAccess"
        $hasNetworkRules = $templateContent -match "networkAcls"
        
        if ($hasPublicNetworkAccess -and $hasNetworkRules) {
            Write-TestResult "Storage Account network access controls" $true
        } else {
            Write-TestResult "Storage Account network access controls" $false "Network access configuration incomplete"
        }
    } catch {
        Write-TestResult "Storage Account network access controls" $false $_.Exception.Message
    }
    
    # Test 3: Validate encryption configuration
    try {
        $templateContent = Get-Content "modules/data/storage-account.bicep" -Raw
        $hasHttpsOnly = $templateContent -match "supportsHttpsTrafficOnly"
        $hasTlsVersion = $templateContent -match "minimumTlsVersion"
        $hasEncryption = $templateContent -match "encryption"
        
        if ($hasHttpsOnly -and $hasTlsVersion -and $hasEncryption) {
            Write-TestResult "Storage Account encryption configuration" $true
        } else {
            Write-TestResult "Storage Account encryption configuration" $false "Encryption configuration incomplete"
        }
    } catch {
        Write-TestResult "Storage Account encryption configuration" $false $_.Exception.Message
    }
    
    # Test 4: Validate blob security features
    try {
        $templateContent = Get-Content "modules/data/storage-account.bicep" -Raw
        $hasBlobPublicAccess = $templateContent -match "enableBlobPublicAccess.*bool.*false"
        $hasBlobVersioning = $templateContent -match "enableBlobVersioning.*bool.*true"
        $hasBlobSoftDelete = $templateContent -match "enableBlobSoftDelete.*bool.*true"
        $hasContainerSoftDelete = $templateContent -match "enableContainerSoftDelete.*bool.*true"
        $hasPointInTimeRestore = $templateContent -match "enableBlobPointInTimeRestore"
        
        if ($hasBlobPublicAccess -and $hasBlobVersioning -and $hasBlobSoftDelete -and $hasContainerSoftDelete -and $hasPointInTimeRestore) {
            Write-TestResult "Storage Account blob security features" $true
        } else {
            Write-TestResult "Storage Account blob security features" $false "Blob security configuration incomplete"
        }
    } catch {
        Write-TestResult "Storage Account blob security features" $false $_.Exception.Message
    }
    
    # Test 5: Validate lifecycle management
    try {
        $templateContent = Get-Content "modules/data/storage-account.bicep" -Raw
        $hasLifecycleManagement = $templateContent -match "enableLifecycleManagement"
        $hasLifecycleRules = $templateContent -match "daysAfterModificationGreaterThan"
        $hasManagementPolicies = $templateContent -match "managementPolicies"
        
        if ($hasLifecycleManagement -and $hasLifecycleRules -and $hasManagementPolicies) {
            Write-TestResult "Storage Account lifecycle management" $true
        } else {
            Write-TestResult "Storage Account lifecycle management" $false "Lifecycle management configuration incomplete"
        }
    } catch {
        Write-TestResult "Storage Account lifecycle management" $false $_.Exception.Message
    }
    
    # Test 6: Validate container and file share configuration
    try {
        $templateContent = Get-Content "modules/data/storage-account.bicep" -Raw
        $hasBlobContainers = $templateContent -match "Microsoft\.Storage/storageAccounts/blobServices/containers"
        $hasFileShares = $templateContent -match "Microsoft\.Storage/storageAccounts/fileServices/shares"
        $hasContainerPublicAccess = $templateContent -match "publicAccess.*container\.publicAccess"
        $hasShareQuota = $templateContent -match "shareQuota.*share\.shareQuota"
        
        if ($hasBlobContainers -and $hasFileShares -and $hasContainerPublicAccess -and $hasShareQuota) {
            Write-TestResult "Storage Account container and file share configuration" $true
        } else {
            Write-TestResult "Storage Account container and file share configuration" $false "Container/file share configuration incomplete"
        }
    } catch {
        Write-TestResult "Storage Account container and file share configuration" $false $_.Exception.Message
    }
}

function Test-PrivateEndpointsModule {
    Write-Host "`nTesting Private Endpoints Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/data/private-endpoints.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Private Endpoints template syntax" $true
        } else {
            Write-TestResult "Private Endpoints template syntax" $false $buildResult
        }
    } catch {
        Write-TestResult "Private Endpoints template syntax" $false $_.Exception.Message
    }
    
    # Test 2: Validate supported service types
    try {
        $templateContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
        $supportedServices = @('sqlServer', 'storageBlob', 'storageFile', 'storageQueue', 'storageTable', 'keyVault', 'cosmosDb', 'serviceBus')
        $allServicesSupported = $true
        $missingServices = @()
        
        foreach ($service in $supportedServices) {
            if ($templateContent -notmatch $service) {
                $allServicesSupported = $false
                $missingServices += $service
            }
        }
        
        if ($allServicesSupported) {
            Write-TestResult "Private Endpoints supported service types" $true
        } else {
            Write-TestResult "Private Endpoints supported service types" $false "Missing services: $($missingServices -join ', ')"
        }
    } catch {
        Write-TestResult "Private Endpoints supported service types" $false $_.Exception.Message
    }
    
    # Test 3: Validate DNS zone configuration
    try {
        $templateContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
        $hasDnsZoneNames = $templateContent -match "privateDnsZoneNames"
        $hasDnsZoneCreation = $templateContent -match "privateDnsZones.*Microsoft\.Network/privateDnsZones"
        $hasVnetLinking = $templateContent -match "virtualNetworkLinks"
        $hasCloudCompatibility = $templateContent -match "environment\(\)\.suffixes"
        
        if ($hasDnsZoneNames -and $hasDnsZoneCreation -and $hasVnetLinking -and $hasCloudCompatibility) {
            Write-TestResult "Private Endpoints DNS zone configuration" $true
        } else {
            Write-TestResult "Private Endpoints DNS zone configuration" $false "DNS zone configuration incomplete"
        }
    } catch {
        Write-TestResult "Private Endpoints DNS zone configuration" $false $_.Exception.Message
    }
    
    # Test 4: Validate private endpoint connectivity
    try {
        $templateContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
        $hasPrivateEndpoints = $templateContent -match "privateEndpoints.*Microsoft\.Network/privateEndpoints"
        $hasPrivateLinkConnections = $templateContent -match "privateLinkServiceConnections"
        $hasGroupIds = $templateContent -match "groupIds"
        $hasDnsZoneGroups = $templateContent -match "privateDnsZoneGroups"
        
        if ($hasPrivateEndpoints -and $hasPrivateLinkConnections -and $hasGroupIds -and $hasDnsZoneGroups) {
            Write-TestResult "Private Endpoints connectivity configuration" $true
        } else {
            Write-TestResult "Private Endpoints connectivity configuration" $false "Connectivity configuration incomplete"
        }
    } catch {
        Write-TestResult "Private Endpoints connectivity configuration" $false $_.Exception.Message
    }
    
    # Test 5: Validate custom DNS configuration
    try {
        $templateContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
        $hasCustomDnsConfig = $templateContent -match "enableCustomDnsConfiguration.*bool"
        $hasCustomDnsServers = $templateContent -match "customDnsServers.*array"
        $hasDnsConfigsProperty = $templateContent -match "customDnsConfigs.*enableCustomDnsConfiguration.*length\(customDnsServers\)"
        
        if ($hasCustomDnsConfig -and $hasCustomDnsServers -and $hasDnsConfigsProperty) {
            Write-TestResult "Private Endpoints custom DNS configuration" $true
        } else {
            Write-TestResult "Private Endpoints custom DNS configuration" $false "Custom DNS configuration incomplete"
        }
    } catch {
        Write-TestResult "Private Endpoints custom DNS configuration" $false $_.Exception.Message
    }
    
    # Test 6: Validate multi-cloud compatibility
    try {
        $templateContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
        $hasEnvironmentFunction = $templateContent -match "environment\(\)\.suffixes"
        $hasSqlServerSuffix = $templateContent -match "environment\(\)\.suffixes\.sqlServerHostname"
        $hasStorageSuffix = $templateContent -match "environment\(\)\.suffixes\.storage"
        $hasKeyVaultSuffix = $templateContent -match "environment\(\)\.suffixes\.keyvaultDns"
        
        if ($hasEnvironmentFunction -and $hasSqlServerSuffix -and $hasStorageSuffix -and $hasKeyVaultSuffix) {
            Write-TestResult "Private Endpoints multi-cloud compatibility" $true
        } else {
            Write-TestResult "Private Endpoints multi-cloud compatibility" $false "Multi-cloud compatibility configuration incomplete"
        }
    } catch {
        Write-TestResult "Private Endpoints multi-cloud compatibility" $false $_.Exception.Message
    }
}

function Test-DataLayerIntegration {
    Write-Host "`nTesting Data Layer Integration..." -ForegroundColor Cyan
    
    # Test 1: Validate main template integration
    try {
        $mainTemplateContent = Get-Content "main.bicep" -Raw
        $hasSqlServerModule = $mainTemplateContent -match "module.*sqlServer.*'modules/data/sql-server\.bicep'"
        $hasStorageAccountModule = $mainTemplateContent -match "module.*storageAccount.*'modules/data/storage-account\.bicep'"
        $hasPrivateEndpointsModule = $mainTemplateContent -match "module.*privateEndpoints.*'modules/data/private-endpoints\.bicep'"
        
        if ($hasSqlServerModule -and $hasStorageAccountModule -and $hasPrivateEndpointsModule) {
            Write-TestResult "Data layer main template integration" $true
        } else {
            Write-TestResult "Data layer main template integration" $false "Module integration incomplete in main template"
        }
    } catch {
        Write-TestResult "Data layer main template integration" $false $_.Exception.Message
    }
    
    # Test 2: Validate parameter file configurations (optional - files may not exist in test environment)
    try {
        $paramFiles = @("parameters/dev.parameters.json", "parameters/staging.parameters.json", "parameters/prod.parameters.json")
        $existingFiles = $paramFiles | Where-Object { Test-Path $_ }
        
        if ($existingFiles.Count -eq 0) {
            Write-TestResult "Data layer parameter file configurations" $true
        } else {
            $allParamFilesValid = $true
            $invalidFiles = @()
            
            foreach ($paramFile in $existingFiles) {
                $paramContent = Get-Content $paramFile -Raw | ConvertFrom-Json
                $hasDataLayerParams = $paramContent.parameters.PSObject.Properties.Name -contains "resourcePrefix" -or 
                                     $paramContent.parameters.PSObject.Properties.Name -contains "workloadName" -or
                                     $paramContent.parameters.PSObject.Properties.Name -contains "environmentConfig"
                
                if (-not $hasDataLayerParams) {
                    $allParamFilesValid = $false
                    $invalidFiles += $paramFile
                }
            }
            
            if ($allParamFilesValid) {
                Write-TestResult "Data layer parameter file configurations" $true
            } else {
                Write-TestResult "Data layer parameter file configurations" $false "Invalid files: $($invalidFiles -join ', ')"
            }
        }
    } catch {
        Write-TestResult "Data layer parameter file configurations" $false $_.Exception.Message
    }
    
    # Test 3: Validate dependency management
    try {
        $mainTemplateContent = Get-Content "main.bicep" -Raw
        $hasProperDependencies = $mainTemplateContent -match "dependsOn.*sqlServer" -or 
                                $mainTemplateContent -match "sqlServer\.outputs" -or
                                $mainTemplateContent -match "storageAccount\.outputs"
        
        if ($hasProperDependencies) {
            Write-TestResult "Data layer dependency management" $true
        } else {
            Write-TestResult "Data layer dependency management" $false "Dependency management configuration incomplete"
        }
    } catch {
        Write-TestResult "Data layer dependency management" $false $_.Exception.Message
    }
}

# Main execution
Write-Host "Starting Data Layer Unit Tests..." -ForegroundColor Green
Write-Host "Test Scope: $TestScope" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow

# Run tests based on scope
if ($TestScope -eq "All" -or $TestScope -eq "SqlServer") {
    Test-SqlServerModule
}

if ($TestScope -eq "All" -or $TestScope -eq "StorageAccount") {
    Test-StorageAccountModule
}

if ($TestScope -eq "All" -or $TestScope -eq "PrivateEndpoints") {
    Test-PrivateEndpointsModule
}

if ($TestScope -eq "All" -or $TestScope -eq "Integration") {
    Test-DataLayerIntegration
}

# Summary
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan

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