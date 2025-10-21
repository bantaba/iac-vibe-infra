# Test script for Private Endpoints module
# This script validates the private endpoints module configuration and deployment

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "test-private-endpoints-rg",
    
    [Parameter(Mandatory=$false)]
    [switch]$ValidateOnly = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colors = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow
        "Blue" = [ConsoleColor]::Blue
        "White" = [ConsoleColor]::White
        "Cyan" = [ConsoleColor]::Cyan
    }
    
    Write-Host $Message -ForegroundColor $colors[$Color]
}

# Function to test private endpoints module syntax
function Test-PrivateEndpointsModuleSyntax {
    Write-ColorOutput "Testing Private Endpoints module syntax..." "Blue"
    
    try {
        $buildResult = az bicep build --file "modules/data/private-endpoints.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✓ Private Endpoints module syntax is valid" "Green"
            return $true
        } else {
            Write-ColorOutput "✗ Private Endpoints module syntax validation failed:" "Red"
            Write-ColorOutput $buildResult "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "✗ Error testing Private Endpoints module syntax: $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to test private endpoints configuration
function Test-PrivateEndpointsConfiguration {
    Write-ColorOutput "Testing Private Endpoints configuration..." "Blue"
    
    $testConfig = @{
        privateEndpointNamePrefix = "test-pe"
        subnetId = "/subscriptions/test/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/data-tier"
        virtualNetworkId = "/subscriptions/test/resourceGroups/test/providers/Microsoft.Network/virtualNetworks/test-vnet"
        privateEndpointConfigs = @(
            @{
                name = "sql-server"
                privateLinkServiceId = "/subscriptions/test/resourceGroups/test/providers/Microsoft.Sql/servers/test-sql"
                groupId = "sqlServer"
            },
            @{
                name = "storage-blob"
                privateLinkServiceId = "/subscriptions/test/resourceGroups/test/providers/Microsoft.Storage/storageAccounts/teststorage"
                groupId = "storageBlob"
            }
        )
        enablePrivateDnsZones = $true
        tags = @{
            Environment = $Environment
            TestRun = "true"
        }
        location = "East US"
    }
    
    # Create a temporary parameter file for testing
    $tempParamFile = "temp-private-endpoints-test.json"
    $paramContent = @{
        '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
        contentVersion = "1.0.0.0"
        parameters = @{}
    }
    
    foreach ($key in $testConfig.Keys) {
        $paramContent.parameters[$key] = @{ value = $testConfig[$key] }
    }
    
    try {
        $paramContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempParamFile -Encoding UTF8
        
        # Validate the deployment
        $validateResult = az deployment group validate `
            --resource-group $ResourceGroupName `
            --template-file "modules/data/private-endpoints.bicep" `
            --parameters "@$tempParamFile" `
            --only-show-errors 2>&1
            
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✓ Private Endpoints configuration is valid" "Green"
            
            if ($VerboseOutput) {
                Write-ColorOutput "Configuration details:" "Cyan"
                Write-ColorOutput "- Endpoint count: $($testConfig.privateEndpointConfigs.Count)" "White"
                Write-ColorOutput "- DNS zones enabled: $($testConfig.enablePrivateDnsZones)" "White"
                Write-ColorOutput "- Environment: $Environment" "White"
            }
            
            return $true
        } else {
            Write-ColorOutput "✗ Private Endpoints configuration validation failed:" "Red"
            Write-ColorOutput $validateResult "Red"
            return $false
        }
    }
    catch {
        Write-ColorOutput "✗ Error testing Private Endpoints configuration: $($_.Exception.Message)" "Red"
        return $false
    }
    finally {
        # Clean up temporary file
        if (Test-Path $tempParamFile) {
            Remove-Item $tempParamFile -Force
        }
    }
}

# Function to test supported service types
function Test-SupportedServiceTypes {
    Write-ColorOutput "Testing supported service types..." "Blue"
    
    $supportedServices = @(
        "sqlServer", "storageBlob", "storageFile", "storageQueue", 
        "storageTable", "keyVault", "cosmosDb", "serviceBus"
    )
    
    $testsPassed = 0
    $totalTests = $supportedServices.Count
    
    foreach ($service in $supportedServices) {
        try {
            # Test that each service type is properly defined in the module
            $moduleContent = Get-Content "modules/data/private-endpoints.bicep" -Raw
            
            if ($moduleContent -match $service) {
                Write-ColorOutput "✓ Service type '$service' is supported" "Green"
                $testsPassed++
            } else {
                Write-ColorOutput "✗ Service type '$service' is not properly configured" "Red"
            }
        }
        catch {
            Write-ColorOutput "✗ Error testing service type '$service': $($_.Exception.Message)" "Red"
        }
    }
    
    if ($testsPassed -eq $totalTests) {
        Write-ColorOutput "✓ All $totalTests service types are properly supported" "Green"
        return $true
    } else {
        Write-ColorOutput "✗ Only $testsPassed out of $totalTests service types passed validation" "Red"
        return $false
    }
}

# Main execution
Write-ColorOutput "=== Private Endpoints Module Test Suite ===" "Cyan"
Write-ColorOutput "Environment: $Environment" "White"
Write-ColorOutput "Resource Group: $ResourceGroupName" "White"
Write-ColorOutput "Validate Only: $ValidateOnly" "White"
Write-ColorOutput "Verbose Output: $VerboseOutput" "White"
Write-ColorOutput "" "White"

$allTestsPassed = $true

# Run syntax validation
if (-not (Test-PrivateEndpointsModuleSyntax)) {
    $allTestsPassed = $false
}

# Run service types validation
if (-not (Test-SupportedServiceTypes)) {
    $allTestsPassed = $false
}

# Run configuration validation (only if resource group exists or we're not doing actual deployment)
if ($ValidateOnly -or (az group exists --name $ResourceGroupName --output tsv) -eq "true") {
    if (-not (Test-PrivateEndpointsConfiguration)) {
        $allTestsPassed = $false
    }
} else {
    Write-ColorOutput "⚠ Skipping configuration validation - resource group '$ResourceGroupName' does not exist" "Yellow"
    Write-ColorOutput "  Use --validate-only flag to skip resource group dependency" "Yellow"
}

Write-ColorOutput "" "White"

# Summary
if ($allTestsPassed) {
    Write-ColorOutput "=== All Private Endpoints tests passed! ===" "Green"
    exit 0
} else {
    Write-ColorOutput "=== Some Private Endpoints tests failed ===" "Red"
    exit 1
}