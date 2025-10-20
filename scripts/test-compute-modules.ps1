# Compute Module Unit Tests
# This script validates Application Gateway and Load Balancer configurations
# Tests core functionality including health probes, SSL termination, and backend pool management

param(
    [Parameter(Mandatory=$false)]
    [string]$TestScope = "All",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
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
    
    if ($Verbose -and $Message) {
        Write-Host "  Details: $Message" -ForegroundColor Gray
    }
}

function Test-ApplicationGatewayModule {
    Write-Host "`nTesting Application Gateway Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/compute/application-gateway.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Application Gateway template syntax" $true
        } else {
            Write-TestResult "Application Gateway template syntax" $false $buildResult
        }
    } catch {
        Write-TestResult "Application Gateway template syntax" $false $_.Exception.Message
    }
    
    # Test 2: Validate required parameters
    try {
        $templateContent = Get-Content "modules/compute/application-gateway.bicep" -Raw
        $requiredParams = @(
            'applicationGatewayName',
            'subnetId', 
            'publicIpAddressId'
        )
        
        $allParamsPresent = $true
        $missingParams = @()
        
        foreach ($param in $requiredParams) {
            if ($templateContent -notmatch "param\s+$param\s") {
                $allParamsPresent = $false
                $missingParams += $param
            }
        }
        
        if ($allParamsPresent) {
            Write-TestResult "Application Gateway required parameters" $true
        } else {
            Write-TestResult "Application Gateway required parameters" $false "Missing: $($missingParams -join ', ')"
        }
    } catch {
        Write-TestResult "Application Gateway required parameters" $false $_.Exception.Message
    }
    
    # Test 3: Validate WAF configuration
    try {
        $templateContent = Get-Content "modules/compute/application-gateway.bicep" -Raw
        $hasWafConfig = $templateContent -match "webApplicationFirewallConfiguration"
        $hasWafPolicy = $templateContent -match "ApplicationGatewayWebApplicationFirewallPolicies"
        
        if ($hasWafConfig -and $hasWafPolicy) {
            Write-TestResult "Application Gateway WAF configuration" $true
        } else {
            Write-TestResult "Application Gateway WAF configuration" $false "WAF configuration or policy missing"
        }
    } catch {
        Write-TestResult "Application Gateway WAF configuration" $false $_.Exception.Message
    }
    
    # Test 4: Validate SSL certificate support
    try {
        $templateContent = Get-Content "modules/compute/application-gateway.bicep" -Raw
        $hasKeyVaultIntegration = $templateContent -match "keyVaultSecretId"
        $hasManagedIdentity = $templateContent -match "UserAssigned"
        
        if ($hasKeyVaultIntegration -and $hasManagedIdentity) {
            Write-TestResult "Application Gateway SSL certificate support" $true
        } else {
            Write-TestResult "Application Gateway SSL certificate support" $false "Key Vault integration or managed identity missing"
        }
    } catch {
        Write-TestResult "Application Gateway SSL certificate support" $false $_.Exception.Message
    }
    
    # Test 5: Validate health probe configuration
    try {
        $templateContent = Get-Content "modules/compute/application-gateway.bicep" -Raw
        $hasHealthProbes = $templateContent -match "probes.*protocol.*path.*interval"
        $hasProbeReference = $templateContent -match "probe.*id.*resourceId"
        
        if ($hasHealthProbes -and $hasProbeReference) {
            Write-TestResult "Application Gateway health probes" $true
        } else {
            Write-TestResult "Application Gateway health probes" $false "Health probe configuration incomplete"
        }
    } catch {
        Write-TestResult "Application Gateway health probes" $false $_.Exception.Message
    }
    
    # Test 6: Validate backend pool management
    try {
        $templateContent = Get-Content "modules/compute/application-gateway.bicep" -Raw
        $hasBackendPools = $templateContent -match "backendAddressPools"
        $hasBackendSettings = $templateContent -match "backendHttpSettingsCollection"
        $hasRoutingRules = $templateContent -match "requestRoutingRules"
        
        if ($hasBackendPools -and $hasBackendSettings -and $hasRoutingRules) {
            Write-TestResult "Application Gateway backend pool management" $true
        } else {
            Write-TestResult "Application Gateway backend pool management" $false "Backend configuration incomplete"
        }
    } catch {
        Write-TestResult "Application Gateway backend pool management" $false $_.Exception.Message
    }
}

function Test-LoadBalancerModule {
    Write-Host "`nTesting Load Balancer Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/compute/load-balancer.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Load Balancer template syntax" $true
        } else {
            Write-TestResult "Load Balancer template syntax" $false $buildResult
        }
    } catch {
        Write-TestResult "Load Balancer template syntax" $false $_.Exception.Message
    }
    
    # Test 2: Validate required parameters
    try {
        $templateContent = Get-Content "modules/compute/load-balancer.bicep" -Raw
        $requiredParams = @(
            'loadBalancerName',
            'subnetId',
            'tier'
        )
        
        $allParamsPresent = $true
        $missingParams = @()
        
        foreach ($param in $requiredParams) {
            if ($templateContent -notmatch "param\s+$param\s") {
                $allParamsPresent = $false
                $missingParams += $param
            }
        }
        
        if ($allParamsPresent) {
            Write-TestResult "Load Balancer required parameters" $true
        } else {
            Write-TestResult "Load Balancer required parameters" $false "Missing: $($missingParams -join ', ')"
        }
    } catch {
        Write-TestResult "Load Balancer required parameters" $false $_.Exception.Message
    }
    
    # Test 3: Validate health probe functionality
    try {
        $templateContent = Get-Content "modules/compute/load-balancer.bicep" -Raw
        $hasHealthProbes = $templateContent -match "probes.*protocol.*port.*intervalInSeconds"
        $hasProbeReference = $templateContent -match "probe.*id.*resourceId"
        $hasHttpProbe = $templateContent -match "Http.*requestPath"
        
        if ($hasHealthProbes -and $hasProbeReference -and $hasHttpProbe) {
            Write-TestResult "Load Balancer health probe functionality" $true
        } else {
            Write-TestResult "Load Balancer health probe functionality" $false "Health probe configuration incomplete"
        }
    } catch {
        Write-TestResult "Load Balancer health probe functionality" $false $_.Exception.Message
    }
    
    # Test 4: Validate load balancing rules
    try {
        $templateContent = Get-Content "modules/compute/load-balancer.bicep" -Raw
        $hasLoadBalancingRules = $templateContent -match "loadBalancingRules"
        $hasFrontendConfig = $templateContent -match "frontendIPConfiguration"
        $hasBackendPool = $templateContent -match "backendAddressPool"
        
        if ($hasLoadBalancingRules -and $hasFrontendConfig -and $hasBackendPool) {
            Write-TestResult "Load Balancer load balancing rules" $true
        } else {
            Write-TestResult "Load Balancer load balancing rules" $false "Load balancing rules configuration incomplete"
        }
    } catch {
        Write-TestResult "Load Balancer load balancing rules" $false $_.Exception.Message
    }
    
    # Test 5: Validate tier-specific configuration
    try {
        $templateContent = Get-Content "modules/compute/load-balancer.bicep" -Raw
        $hasTierParam = $templateContent -match "param\s+tier.*business.*data"
        $hasTierUsage = $templateContent -match "\$\{tier\}"
        
        if ($hasTierParam -and $hasTierUsage) {
            Write-TestResult "Load Balancer tier-specific configuration" $true
        } else {
            Write-TestResult "Load Balancer tier-specific configuration" $false "Tier configuration missing or incomplete"
        }
    } catch {
        Write-TestResult "Load Balancer tier-specific configuration" $false $_.Exception.Message
    }
    
    # Test 6: Validate availability zone support
    try {
        $templateContent = Get-Content "modules/compute/load-balancer.bicep" -Raw
        $hasZones = $templateContent -match "zones.*Standard"
        $hasStandardSku = $templateContent -match "sku.*Standard"
        
        if ($hasZones -and $hasStandardSku) {
            Write-TestResult "Load Balancer availability zone support" $true
        } else {
            Write-TestResult "Load Balancer availability zone support" $false "Availability zone configuration missing"
        }
    } catch {
        Write-TestResult "Load Balancer availability zone support" $false $_.Exception.Message
    }
}

function Test-VirtualMachineModule {
    Write-Host "`nTesting Virtual Machine Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/compute/virtual-machines.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Virtual Machine template syntax" $true
        } else {
            Write-TestResult "Virtual Machine template syntax" $false $buildResult
        }
    } catch {
        Write-TestResult "Virtual Machine template syntax" $false $_.Exception.Message
    }
    
    # Test 2: Validate availability zone deployment
    try {
        $templateContent = Get-Content "modules/compute/virtual-machines.bicep" -Raw
        $hasAvailabilityZones = $templateContent -match "availabilityZones.*zones"
        $hasZoneBalance = $templateContent -match "zoneBalance.*true"
        
        if ($hasAvailabilityZones -and $hasZoneBalance) {
            Write-TestResult "Virtual Machine availability zone deployment" $true
        } else {
            Write-TestResult "Virtual Machine availability zone deployment" $false "Availability zone configuration missing"
        }
    } catch {
        Write-TestResult "Virtual Machine availability zone deployment" $false $_.Exception.Message
    }
    
    # Test 3: Validate autoscaling configuration
    try {
        $templateContent = Get-Content "modules/compute/virtual-machines.bicep" -Raw
        $hasAutoscaleSettings = $templateContent -match "autoscalesettings"
        $hasScaleRules = $templateContent -match "metricTrigger.*scaleAction"
        $hasCpuMetric = $templateContent -match "Percentage CPU"
        
        if ($hasAutoscaleSettings -and $hasScaleRules -and $hasCpuMetric) {
            Write-TestResult "Virtual Machine autoscaling configuration" $true
        } else {
            Write-TestResult "Virtual Machine autoscaling configuration" $false "Autoscaling configuration incomplete"
        }
    } catch {
        Write-TestResult "Virtual Machine autoscaling configuration" $false $_.Exception.Message
    }
}

function Test-AvailabilitySetModule {
    Write-Host "`nTesting Availability Set Module..." -ForegroundColor Cyan
    
    # Test 1: Validate template syntax
    try {
        $buildResult = az bicep build --file "modules/compute/availability-sets.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Availability Set template syntax" $true
        } else {
            Write-TestResult "Availability Set template syntax" $false $buildResult
        }
    } catch {
        Write-TestResult "Availability Set template syntax" $false $_.Exception.Message
    }
    
    # Test 2: Validate fault domain configuration
    try {
        $templateContent = Get-Content "modules/compute/availability-sets.bicep" -Raw
        $hasFaultDomains = $templateContent -match "platformFaultDomainCount"
        $hasUpdateDomains = $templateContent -match "platformUpdateDomainCount"
        
        if ($hasFaultDomains -and $hasUpdateDomains) {
            Write-TestResult "Availability Set fault domain configuration" $true
        } else {
            Write-TestResult "Availability Set fault domain configuration" $false "Fault or update domain configuration missing"
        }
    } catch {
        Write-TestResult "Availability Set fault domain configuration" $false $_.Exception.Message
    }
}

# Main execution
Write-Host "Starting Compute Module Unit Tests..." -ForegroundColor Green
Write-Host "Test Scope: $TestScope" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow

# Run tests based on scope
if ($TestScope -eq "All" -or $TestScope -eq "ApplicationGateway") {
    Test-ApplicationGatewayModule
}

if ($TestScope -eq "All" -or $TestScope -eq "LoadBalancer") {
    Test-LoadBalancerModule
}

if ($TestScope -eq "All" -or $TestScope -eq "VirtualMachine") {
    Test-VirtualMachineModule
}

if ($TestScope -eq "All" -or $TestScope -eq "AvailabilitySet") {
    Test-AvailabilitySetModule
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