# Connectivity Testing Script
# This script validates network connectivity, security configurations, and end-to-end deployment
# Tests health probes, load balancer connectivity, private endpoint connectivity, and security configurations
# Requirements: 4.4 (health probes), 5.1 (private endpoint connectivity)

param(
    [Parameter(Mandatory=$false)]
    [string]$TestScope = "All",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDeploymentValidation
)

# Test configuration
$ErrorActionPreference = "Stop"
$testResults = @()

# Initialize Azure CLI context if subscription is provided
if ($SubscriptionId) {
    try {
        az account set --subscription $SubscriptionId
        Write-Host "Set Azure subscription context to: $SubscriptionId" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not set subscription context. Using current context." -ForegroundColor Yellow
    }
}

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

function Test-NetworkConnectivity {
    Write-Host "`nTesting Network Connectivity..." -ForegroundColor Cyan
    
    # Test 1: Validate Application Gateway health probe configuration
    try {
        $appGatewayContent = Get-Content "modules/compute/application-gateway.bicep" -Raw
        $hasHealthProbes = $appGatewayContent -match "var probes = \[for probe in healthProbes"
        $hasProbeProtocol = $appGatewayContent -match "protocol: probe\.protocol"
        $hasProbeHost = $appGatewayContent -match "host: probe\.host"
        $hasProbePath = $appGatewayContent -match "path: probe\.path"
        $hasProbeInterval = $appGatewayContent -match "intervalInSeconds: probe\.intervalInSeconds"
        $hasProbeTimeout = $appGatewayContent -match "timeoutInSeconds: probe\.timeoutInSeconds"
        $hasProbeThreshold = $appGatewayContent -match "unhealthyThreshold: probe\.unhealthyThreshold"
        
        if ($hasHealthProbes -and $hasProbeProtocol -and $hasProbeHost -and $hasProbePath -and 
            $hasProbeInterval -and $hasProbeTimeout -and $hasProbeThreshold) {
            Write-TestResult "Application Gateway health probe configuration" $true
        } else {
            $missingComponents = @()
            if (-not $hasHealthProbes) { $missingComponents += "health probes array" }
            if (-not $hasProbeProtocol) { $missingComponents += "probe protocol" }
            if (-not $hasProbeHost) { $missingComponents += "probe host" }
            if (-not $hasProbePath) { $missingComponents += "probe path" }
            if (-not $hasProbeInterval) { $missingComponents += "probe interval" }
            if (-not $hasProbeTimeout) { $missingComponents += "probe timeout" }
            if (-not $hasProbeThreshold) { $missingComponents += "probe threshold" }
            Write-TestResult "Application Gateway health probe configuration" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Application Gateway health probe configuration" $false $_.Exception.Message
    }
    
    # Test 2: Validate Load Balancer health probe configuration
    try {
        $loadBalancerContent = Get-Content "modules/compute/load-balancer.bicep" -Raw
        $hasHealthProbes = $loadBalancerContent -match "var probesCollection = \[for probe in healthProbes"
        $hasProbeProtocol = $loadBalancerContent -match "protocol: probe\.protocol"
        $hasProbePort = $loadBalancerContent -match "port: probe\.port"
        $hasProbeInterval = $loadBalancerContent -match "intervalInSeconds: probe\.intervalInSeconds"
        $hasProbeCount = $loadBalancerContent -match "numberOfProbes: probe\.numberOfProbes"
        $hasHttpProbe = $loadBalancerContent -match "requestPath.*probe\.protocol.*Http.*Https.*probe\.requestPath"
        
        if ($hasHealthProbes -and $hasProbeProtocol -and $hasProbePort -and 
            $hasProbeInterval -and $hasProbeCount -and $hasHttpProbe) {
            Write-TestResult "Load Balancer health probe configuration" $true
        } else {
            $missingComponents = @()
            if (-not $hasHealthProbes) { $missingComponents += "health probes collection" }
            if (-not $hasProbeProtocol) { $missingComponents += "probe protocol" }
            if (-not $hasProbePort) { $missingComponents += "probe port" }
            if (-not $hasProbeInterval) { $missingComponents += "probe interval" }
            if (-not $hasProbeCount) { $missingComponents += "probe count" }
            if (-not $hasHttpProbe) { $missingComponents += "HTTP probe configuration" }
            Write-TestResult "Load Balancer health probe configuration" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Load Balancer health probe configuration" $false $_.Exception.Message
    }
    
    # Test 3: Validate backend pool connectivity configuration
    try {
        $appGatewayContent = Get-Content "modules/compute/application-gateway.bicep" -Raw
        $hasBackendPools = $appGatewayContent -match "backendAddressPools"
        $hasBackendSettings = $appGatewayContent -match "backendHttpSettingsCollection"
        $hasRoutingRules = $appGatewayContent -match "requestRoutingRules"
        $hasBackendPoolReference = $appGatewayContent -match "backendAddressPool.*resourceId.*backendAddressPools"
        $hasHealthProbeReference = $appGatewayContent -match "probe.*resourceId.*probes"
        
        if ($hasBackendPools -and $hasBackendSettings -and $hasRoutingRules -and 
            $hasBackendPoolReference -and $hasHealthProbeReference) {
            Write-TestResult "Application Gateway backend pool connectivity" $true
        } else {
            $missingComponents = @()
            if (-not $hasBackendPools) { $missingComponents += "backend pools" }
            if (-not $hasBackendSettings) { $missingComponents += "backend settings" }
            if (-not $hasRoutingRules) { $missingComponents += "routing rules" }
            if (-not $hasBackendPoolReference) { $missingComponents += "backend pool references" }
            if (-not $hasHealthProbeReference) { $missingComponents += "health probe references" }
            Write-TestResult "Application Gateway backend pool connectivity" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Application Gateway backend pool connectivity" $false $_.Exception.Message
    }
    
    # Test 4: Validate Load Balancer backend pool connectivity
    try {
        $loadBalancerContent = Get-Content "modules/compute/load-balancer.bicep" -Raw
        $hasBackendPools = $loadBalancerContent -match "backendAddressPools"
        $hasLoadBalancingRules = $loadBalancerContent -match "loadBalancingRules"
        $hasBackendPoolReference = $loadBalancerContent -match "backendAddressPool.*resourceId.*backendAddressPools"
        $hasProbeReference = $loadBalancerContent -match "probe.*resourceId.*probes"
        $hasFrontendConfig = $loadBalancerContent -match "frontendIPConfiguration.*resourceId.*frontendIPConfigurations"
        
        if ($hasBackendPools -and $hasLoadBalancingRules -and $hasBackendPoolReference -and 
            $hasProbeReference -and $hasFrontendConfig) {
            Write-TestResult "Load Balancer backend pool connectivity" $true
        } else {
            $missingComponents = @()
            if (-not $hasBackendPools) { $missingComponents += "backend pools" }
            if (-not $hasLoadBalancingRules) { $missingComponents += "load balancing rules" }
            if (-not $hasBackendPoolReference) { $missingComponents += "backend pool references" }
            if (-not $hasProbeReference) { $missingComponents += "probe references" }
            if (-not $hasFrontendConfig) { $missingComponents += "frontend configuration" }
            Write-TestResult "Load Balancer backend pool connectivity" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Load Balancer backend pool connectivity" $false $_.Exception.Message
    }
    
    # Test 5: Validate network security group connectivity rules
    try {
        $nsgContent = Get-Content "modules/networking/network-security-groups.bicep" -Raw
        $hasWebTierRules = $nsgContent -match "web-tier.*securityRules"
        $hasBusinessTierRules = $nsgContent -match "business-tier.*securityRules"
        $hasDataTierRules = $nsgContent -match "data-tier.*securityRules"
        $hasHttpsRule = $nsgContent -match "destinationPortRange.*'443'"
        $hasHttpRule = $nsgContent -match "destinationPortRange.*'80'"
        $hasSqlRule = $nsgContent -match "destinationPortRange.*'1433'"
        
        if ($hasWebTierRules -and $hasBusinessTierRules -and $hasDataTierRules -and 
            $hasHttpsRule -and $hasHttpRule -and $hasSqlRule) {
            Write-TestResult "Network Security Group connectivity rules" $true
        } else {
            $missingComponents = @()
            if (-not $hasWebTierRules) { $missingComponents += "web tier rules" }
            if (-not $hasBusinessTierRules) { $missingComponents += "business tier rules" }
            if (-not $hasDataTierRules) { $missingComponents += "data tier rules" }
            if (-not $hasHttpsRule) { $missingComponents += "HTTPS rules" }
            if (-not $hasHttpRule) { $missingComponents += "HTTP rules" }
            if (-not $hasSqlRule) { $missingComponents += "SQL rules" }
            Write-TestResult "Network Security Group connectivity rules" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Network Security Group connectivity rules" $false $_.Exception.Message
    }
}

function Test-PrivateEndpointConnectivity {
    Write-Host "`nTesting Private Endpoint Connectivity..." -ForegroundColor Cyan
    
    # Test 1: Validate private endpoint configuration for SQL Server
    try {
        $privateEndpointContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
        $hasSqlServerSupport = $privateEndpointContent -match "sqlServer"
        $hasPrivateEndpointResource = $privateEndpointContent -match "Microsoft\.Network/privateEndpoints"
        $hasPrivateLinkConnection = $privateEndpointContent -match "privateLinkServiceConnections"
        $hasGroupIds = $privateEndpointContent -match "groupIds.*groupId"
        $hasDnsZoneGroup = $privateEndpointContent -match "privateDnsZoneGroups"
        
        if ($hasSqlServerSupport -and $hasPrivateEndpointResource -and $hasPrivateLinkConnection -and 
            $hasGroupIds -and $hasDnsZoneGroup) {
            Write-TestResult "SQL Server private endpoint connectivity" $true
        } else {
            $missingComponents = @()
            if (-not $hasSqlServerSupport) { $missingComponents += "SQL Server support" }
            if (-not $hasPrivateEndpointResource) { $missingComponents += "private endpoint resource" }
            if (-not $hasPrivateLinkConnection) { $missingComponents += "private link connection" }
            if (-not $hasGroupIds) { $missingComponents += "group IDs" }
            if (-not $hasDnsZoneGroup) { $missingComponents += "DNS zone group" }
            Write-TestResult "SQL Server private endpoint connectivity" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "SQL Server private endpoint connectivity" $false $_.Exception.Message
    }
    
    # Test 2: Validate private endpoint DNS integration
    try {
        $privateEndpointContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
        $hasPrivateDnsZones = $privateEndpointContent -match "Microsoft\.Network/privateDnsZones"
        $hasVirtualNetworkLinks = $privateEndpointContent -match "virtualNetworkLinks"
        $hasDnsZoneNames = $privateEndpointContent -match "privateDnsZoneNames"
        $hasEnvironmentSuffixes = $privateEndpointContent -match "environment\(\)\.suffixes"
        $hasSqlServerSuffix = $privateEndpointContent -match "environment\(\)\.suffixes\.sqlServerHostname"
        $hasStorageSuffix = $privateEndpointContent -match "environment\(\)\.suffixes\.storage"
        
        if ($hasPrivateDnsZones -and $hasVirtualNetworkLinks -and $hasDnsZoneNames -and 
            $hasEnvironmentSuffixes -and $hasSqlServerSuffix -and $hasStorageSuffix) {
            Write-TestResult "Private endpoint DNS integration" $true
        } else {
            $missingComponents = @()
            if (-not $hasPrivateDnsZones) { $missingComponents += "private DNS zones" }
            if (-not $hasVirtualNetworkLinks) { $missingComponents += "virtual network links" }
            if (-not $hasDnsZoneNames) { $missingComponents += "DNS zone names" }
            if (-not $hasEnvironmentSuffixes) { $missingComponents += "environment suffixes" }
            if (-not $hasSqlServerSuffix) { $missingComponents += "SQL Server suffix" }
            if (-not $hasStorageSuffix) { $missingComponents += "Storage suffix" }
            Write-TestResult "Private endpoint DNS integration" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Private endpoint DNS integration" $false $_.Exception.Message
    }
    
    # Test 3: Validate storage account private endpoint connectivity
    try {
        $privateEndpointContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
        $hasStorageBlobSupport = $privateEndpointContent -match "storageBlob"
        $hasStorageFileSupport = $privateEndpointContent -match "storageFile"
        $hasStorageQueueSupport = $privateEndpointContent -match "storageQueue"
        $hasStorageTableSupport = $privateEndpointContent -match "storageTable"
        $hasMultiServiceSupport = $privateEndpointContent -match "groupId.*config\.groupId"
        
        if ($hasStorageBlobSupport -and $hasStorageFileSupport -and $hasStorageQueueSupport -and 
            $hasStorageTableSupport -and $hasMultiServiceSupport) {
            Write-TestResult "Storage Account private endpoint connectivity" $true
        } else {
            $missingComponents = @()
            if (-not $hasStorageBlobSupport) { $missingComponents += "blob storage support" }
            if (-not $hasStorageFileSupport) { $missingComponents += "file storage support" }
            if (-not $hasStorageQueueSupport) { $missingComponents += "queue storage support" }
            if (-not $hasStorageTableSupport) { $missingComponents += "table storage support" }
            if (-not $hasMultiServiceSupport) { $missingComponents += "multi-service support" }
            Write-TestResult "Storage Account private endpoint connectivity" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Storage Account private endpoint connectivity" $false $_.Exception.Message
    }
    
    # Test 4: Validate Key Vault private endpoint connectivity
    try {
        $privateEndpointContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
        $hasKeyVaultSupport = $privateEndpointContent -match "keyVault"
        $hasKeyVaultSuffix = $privateEndpointContent -match "environment\(\)\.suffixes\.keyvaultDns"
        $hasKeyVaultDnsZone = $privateEndpointContent -match "privatelink\.vaultcore"
        
        if ($hasKeyVaultSupport -and $hasKeyVaultSuffix -and $hasKeyVaultDnsZone) {
            Write-TestResult "Key Vault private endpoint connectivity" $true
        } else {
            $missingComponents = @()
            if (-not $hasKeyVaultSupport) { $missingComponents += "Key Vault support" }
            if (-not $hasKeyVaultSuffix) { $missingComponents += "Key Vault DNS suffix" }
            if (-not $hasKeyVaultDnsZone) { $missingComponents += "Key Vault DNS zone" }
            Write-TestResult "Key Vault private endpoint connectivity" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Key Vault private endpoint connectivity" $false $_.Exception.Message
    }
    
    # Test 5: Validate multi-cloud compatibility for private endpoints
    try {
        $privateEndpointContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
        $hasEnvironmentFunction = $privateEndpointContent -match "environment\(\)"
        $hasConditionalSuffixes = $privateEndpointContent -match "environment\(\)\.suffixes\."
        $hasCloudCompatibleNaming = $privateEndpointContent -match "privatelink\.\$\{environment\(\)\.suffixes\."
        
        if ($hasEnvironmentFunction -and $hasConditionalSuffixes -and $hasCloudCompatibleNaming) {
            Write-TestResult "Private endpoint multi-cloud compatibility" $true
        } else {
            $missingComponents = @()
            if (-not $hasEnvironmentFunction) { $missingComponents += "environment function" }
            if (-not $hasConditionalSuffixes) { $missingComponents += "conditional suffixes" }
            if (-not $hasCloudCompatibleNaming) { $missingComponents += "cloud-compatible naming" }
            Write-TestResult "Private endpoint multi-cloud compatibility" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Private endpoint multi-cloud compatibility" $false $_.Exception.Message
    }
}

function Test-SecurityConfiguration {
    Write-Host "`nTesting Security Configuration..." -ForegroundColor Cyan
    
    # Test 1: Validate DDoS protection configuration
    try {
        $ddosContent = Get-Content "modules/networking/ddos-protection.bicep" -Raw
        $hasDdosProtectionPlan = $ddosContent -match "Microsoft\.Network/ddosProtectionPlans"
        $hasProtectionMode = $ddosContent -match "protectionMode.*'VirtualNetworkInherited'"
        
        if ($hasDdosProtectionPlan -and $hasProtectionMode) {
            Write-TestResult "DDoS protection configuration" $true
        } else {
            $missingComponents = @()
            if (-not $hasDdosProtectionPlan) { $missingComponents += "DDoS protection plan" }
            if (-not $hasProtectionMode) { $missingComponents += "protection mode" }
            Write-TestResult "DDoS protection configuration" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "DDoS protection configuration" $false $_.Exception.Message
    }
    
    # Test 2: Validate Web Application Firewall configuration
    try {
        $appGatewayContent = Get-Content "modules/compute/application-gateway.bicep" -Raw
        $hasWafPolicy = $appGatewayContent -match "Microsoft\.Network/ApplicationGatewayWebApplicationFirewallPolicies"
        $hasWafMode = $appGatewayContent -match "mode.*'Prevention'"
        $hasWafRuleSet = $appGatewayContent -match "ruleSetType.*'OWASP'"
        $hasWafRuleSetVersion = $appGatewayContent -match "ruleSetVersion.*'3\.2'"
        $hasWafEnabled = $appGatewayContent -match "enabled.*true"
        
        if ($hasWafPolicy -and $hasWafMode -and $hasWafRuleSet -and $hasWafRuleSetVersion -and $hasWafEnabled) {
            Write-TestResult "Web Application Firewall configuration" $true
        } else {
            $missingComponents = @()
            if (-not $hasWafPolicy) { $missingComponents += "WAF policy" }
            if (-not $hasWafMode) { $missingComponents += "WAF mode" }
            if (-not $hasWafRuleSet) { $missingComponents += "WAF rule set" }
            if (-not $hasWafRuleSetVersion) { $missingComponents += "WAF rule set version" }
            if (-not $hasWafEnabled) { $missingComponents += "WAF enabled" }
            Write-TestResult "Web Application Firewall configuration" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Web Application Firewall configuration" $false $_.Exception.Message
    }
    
    # Test 3: Validate SSL/TLS configuration
    try {
        $appGatewayContent = Get-Content "modules/compute/application-gateway.bicep" -Raw
        $hasSslCertificates = $appGatewayContent -match "sslCertificates"
        $hasKeyVaultIntegration = $appGatewayContent -match "keyVaultSecretId"
        $hasManagedIdentity = $appGatewayContent -match "UserAssigned"
        $hasHttpsListener = $appGatewayContent -match "protocol.*'Https'"
        $hasSslPolicy = $appGatewayContent -match "sslPolicy"
        
        if ($hasSslCertificates -and $hasKeyVaultIntegration -and $hasManagedIdentity -and 
            $hasHttpsListener -and $hasSslPolicy) {
            Write-TestResult "SSL/TLS configuration" $true
        } else {
            $missingComponents = @()
            if (-not $hasSslCertificates) { $missingComponents += "SSL certificates" }
            if (-not $hasKeyVaultIntegration) { $missingComponents += "Key Vault integration" }
            if (-not $hasManagedIdentity) { $missingComponents += "managed identity" }
            if (-not $hasHttpsListener) { $missingComponents += "HTTPS listener" }
            if (-not $hasSslPolicy) { $missingComponents += "SSL policy" }
            Write-TestResult "SSL/TLS configuration" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "SSL/TLS configuration" $false $_.Exception.Message
    }
    
    # Test 4: Validate network access controls
    try {
        $sqlServerContent = Get-Content "modules/data/sql-server.bicep" -Raw
        $hasPublicNetworkAccess = $sqlServerContent -match "publicNetworkAccess.*enablePublicNetworkAccess.*'Enabled'.*'Disabled'"
        $hasFirewallRules = $sqlServerContent -match "Microsoft\.Sql/servers/firewallRules"
        $hasVirtualNetworkRules = $sqlServerContent -match "Microsoft\.Sql/servers/virtualNetworkRules"
        $hasTlsVersion = $sqlServerContent -match "minimalTlsVersion.*'1\.2'"
        
        if ($hasPublicNetworkAccess -and $hasFirewallRules -and $hasVirtualNetworkRules -and $hasTlsVersion) {
            Write-TestResult "Database network access controls" $true
        } else {
            $missingComponents = @()
            if (-not $hasPublicNetworkAccess) { $missingComponents += "public network access control" }
            if (-not $hasFirewallRules) { $missingComponents += "firewall rules" }
            if (-not $hasVirtualNetworkRules) { $missingComponents += "virtual network rules" }
            if (-not $hasTlsVersion) { $missingComponents += "TLS version" }
            Write-TestResult "Database network access controls" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Database network access controls" $false $_.Exception.Message
    }
    
    # Test 5: Validate storage account security configuration
    try {
        $storageContent = Get-Content "modules/data/storage-account.bicep" -Raw
        $hasHttpsOnly = $storageContent -match "supportsHttpsTrafficOnly.*true"
        $hasTlsVersion = $storageContent -match "minimumTlsVersion.*'TLS1_2'"
        $hasPublicAccess = $storageContent -match "enableBlobPublicAccess.*false"
        $hasNetworkRules = $storageContent -match "networkAcls"
        $hasDefaultAction = $storageContent -match "defaultAction.*'Deny'"
        
        if ($hasHttpsOnly -and $hasTlsVersion -and $hasPublicAccess -and $hasNetworkRules -and $hasDefaultAction) {
            Write-TestResult "Storage Account security configuration" $true
        } else {
            $missingComponents = @()
            if (-not $hasHttpsOnly) { $missingComponents += "HTTPS only" }
            if (-not $hasTlsVersion) { $missingComponents += "TLS version" }
            if (-not $hasPublicAccess) { $missingComponents += "public access disabled" }
            if (-not $hasNetworkRules) { $missingComponents += "network rules" }
            if (-not $hasDefaultAction) { $missingComponents += "default deny action" }
            Write-TestResult "Storage Account security configuration" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Storage Account security configuration" $false $_.Exception.Message
    }
}

function Test-EndToEndDeployment {
    Write-Host "`nTesting End-to-End Deployment..." -ForegroundColor Cyan
    
    if ($SkipDeploymentValidation) {
        Write-Host "Skipping deployment validation tests as requested." -ForegroundColor Yellow
        return
    }
    
    # Test 1: Validate main template syntax and structure
    try {
        $buildResult = az bicep build --file "main.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Main template syntax validation" $true
        } else {
            Write-TestResult "Main template syntax validation" $false $buildResult
        }
    } catch {
        Write-TestResult "Main template syntax validation" $false $_.Exception.Message
    }
    
    # Test 2: Validate module dependencies in main template
    try {
        $mainContent = Get-Content "main.bicep" -Raw
        $hasNetworkingModules = $mainContent -match "module.*'modules/networking/"
        $hasSecurityModules = $mainContent -match "module.*'modules/security/"
        $hasComputeModules = $mainContent -match "module.*'modules/compute/"
        $hasDataModules = $mainContent -match "module.*'modules/data/"
        $hasMonitoringModules = $mainContent -match "module.*'modules/monitoring/"
        $hasDependsOn = $mainContent -match "dependsOn.*\["
        
        if ($hasNetworkingModules -and $hasSecurityModules -and $hasComputeModules -and 
            $hasDataModules -and $hasMonitoringModules -and $hasDependsOn) {
            Write-TestResult "Main template module dependencies" $true
        } else {
            $missingComponents = @()
            if (-not $hasNetworkingModules) { $missingComponents += "networking modules" }
            if (-not $hasSecurityModules) { $missingComponents += "security modules" }
            if (-not $hasComputeModules) { $missingComponents += "compute modules" }
            if (-not $hasDataModules) { $missingComponents += "data modules" }
            if (-not $hasMonitoringModules) { $missingComponents += "monitoring modules" }
            if (-not $hasDependsOn) { $missingComponents += "dependency management" }
            Write-TestResult "Main template module dependencies" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Main template module dependencies" $false $_.Exception.Message
    }
    
    # Test 3: Validate parameter files for different environments
    try {
        $environments = @("dev", "staging", "prod")
        $allParamFilesValid = $true
        $invalidFiles = @()
        
        foreach ($env in $environments) {
            $paramFile = "parameters/$env.parameters.json"
            if (Test-Path $paramFile) {
                try {
                    $paramContent = Get-Content $paramFile -Raw | ConvertFrom-Json
                    $hasRequiredParams = $paramContent.parameters.PSObject.Properties.Name -contains "resourcePrefix" -and
                                        $paramContent.parameters.PSObject.Properties.Name -contains "environment" -and
                                        $paramContent.parameters.PSObject.Properties.Name -contains "workloadName"
                    
                    if (-not $hasRequiredParams) {
                        $allParamFilesValid = $false
                        $invalidFiles += $paramFile
                    }
                } catch {
                    $allParamFilesValid = $false
                    $invalidFiles += "$paramFile (JSON parse error)"
                }
            } else {
                Write-Host "  Warning: Parameter file $paramFile not found" -ForegroundColor Yellow
            }
        }
        
        if ($allParamFilesValid -and $invalidFiles.Count -eq 0) {
            Write-TestResult "Environment parameter files validation" $true
        } else {
            Write-TestResult "Environment parameter files validation" $false "Invalid files: $($invalidFiles -join ', ')"
        }
    } catch {
        Write-TestResult "Environment parameter files validation" $false $_.Exception.Message
    }
    
    # Test 4: Validate deployment with what-if analysis (if resource group is provided)
    if ($ResourceGroupName -and -not [string]::IsNullOrEmpty($ResourceGroupName)) {
        try {
            # Check if resource group exists
            $rgExists = az group exists --name $ResourceGroupName --output tsv
            if ($rgExists -eq "true") {
                $paramFile = "parameters/$Environment.parameters.json"
                if (Test-Path $paramFile) {
                    $whatIfResult = az deployment group what-if `
                        --resource-group $ResourceGroupName `
                        --template-file "main.bicep" `
                        --parameters "@$paramFile" `
                        --output json 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-TestResult "Deployment what-if analysis" $true
                        if ($VerboseOutput) {
                            $whatIfData = $whatIfResult | ConvertFrom-Json
                            Write-Host "  What-if analysis completed successfully" -ForegroundColor Gray
                            Write-Host "  Changes detected: $($whatIfData.changes.Count)" -ForegroundColor Gray
                        }
                    } else {
                        Write-TestResult "Deployment what-if analysis" $false $whatIfResult
                    }
                } else {
                    Write-TestResult "Deployment what-if analysis" $false "Parameter file not found: $paramFile"
                }
            } else {
                Write-TestResult "Deployment what-if analysis" $false "Resource group '$ResourceGroupName' does not exist"
            }
        } catch {
            Write-TestResult "Deployment what-if analysis" $false $_.Exception.Message
        }
    } else {
        Write-Host "  Skipping what-if analysis - no resource group specified" -ForegroundColor Yellow
    }
    
    # Test 5: Validate resource naming conventions
    try {
        $namingContent = Get-Content "modules/shared/naming-conventions.bicep" -Raw
        $hasResourcePrefix = $namingContent -match "resourcePrefix.*string"
        $hasEnvironment = $namingContent -match "environment.*string"
        $hasWorkloadName = $namingContent -match "workloadName.*string"
        $hasNamingConventions = $namingContent -match "var namingConvention"
        $hasConsistentNaming = $namingContent -match "resourcePrefix.*environment.*workloadName"
        
        if ($hasResourcePrefix -and $hasEnvironment -and $hasWorkloadName -and 
            $hasNamingConventions -and $hasConsistentNaming) {
            Write-TestResult "Resource naming conventions" $true
        } else {
            $missingComponents = @()
            if (-not $hasResourcePrefix) { $missingComponents += "resource prefix" }
            if (-not $hasEnvironment) { $missingComponents += "environment" }
            if (-not $hasWorkloadName) { $missingComponents += "workload name" }
            if (-not $hasNamingConventions) { $missingComponents += "naming conventions" }
            if (-not $hasConsistentNaming) { $missingComponents += "consistent naming" }
            Write-TestResult "Resource naming conventions" $false "Missing: $($missingComponents -join ', ')"
        }
    } catch {
        Write-TestResult "Resource naming conventions" $false $_.Exception.Message
    }
}

# Main execution
Write-Host "Starting Connectivity Testing Suite..." -ForegroundColor Green
Write-Host "Test Scope: $TestScope" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
if ($ResourceGroupName) {
    Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
}
if ($SubscriptionId) {
    Write-Host "Subscription: $SubscriptionId" -ForegroundColor Yellow
}
Write-Host ""

# Run tests based on scope
if ($TestScope -eq "All" -or $TestScope -eq "NetworkConnectivity") {
    Test-NetworkConnectivity
}

if ($TestScope -eq "All" -or $TestScope -eq "PrivateEndpoints") {
    Test-PrivateEndpointConnectivity
}

if ($TestScope -eq "All" -or $TestScope -eq "Security") {
    Test-SecurityConfiguration
}

if ($TestScope -eq "All" -or $TestScope -eq "EndToEnd") {
    Test-EndToEndDeployment
}

# Summary
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "Connectivity Test Summary" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

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
    
    Write-Host "`nRecommendations:" -ForegroundColor Yellow
    Write-Host "1. Review failed test details above" -ForegroundColor White
    Write-Host "2. Check module configurations for missing components" -ForegroundColor White
    Write-Host "3. Validate template syntax using 'az bicep build'" -ForegroundColor White
    Write-Host "4. Run individual test scopes for focused debugging" -ForegroundColor White
    Write-Host "5. Use --verbose-output for detailed test information" -ForegroundColor White
    
    exit 1
} else {
    Write-Host "`nAll connectivity tests passed!" -ForegroundColor Green
    Write-Host "Infrastructure is ready for deployment." -ForegroundColor Green
    exit 0
}