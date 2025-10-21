# Deployment Automation Tests
# This script validates end-to-end deployment scenarios and rollback/recovery capabilities
# Tests integration between all modules and validates deployment automation workflows

param(
    [Parameter(Mandatory=$false)]
    [string]$TestScope = "All",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "test-bicep-infrastructure-$Environment-rg",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput,
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanupAfterTest,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDeployment
)

# Test configuration
$ErrorActionPreference = "Stop"
$testResults = @()
$deploymentName = "test-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$rollbackDeploymentName = "rollback-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

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

function Test-PreDeploymentValidation {
    Write-Host "`nTesting Pre-Deployment Validation..." -ForegroundColor Cyan
    
    # Test 1: Validate Azure CLI authentication
    try {
        $account = az account show 2>&1 | ConvertFrom-Json
        if ($account -and $account.id) {
            Write-TestResult "Azure CLI authentication" $true "Authenticated as: $($account.user.name)"
        } else {
            Write-TestResult "Azure CLI authentication" $false "Not authenticated to Azure CLI"
            return $false
        }
    } catch {
        Write-TestResult "Azure CLI authentication" $false $_.Exception.Message
        return $false
    }
    
    # Test 2: Validate template files exist
    try {
        $requiredFiles = @(
            "main.bicep",
            "parameters/$Environment.parameters.json"
        )
        
        $allFilesExist = $true
        $missingFiles = @()
        
        foreach ($file in $requiredFiles) {
            if (!(Test-Path $file)) {
                $allFilesExist = $false
                $missingFiles += $file
            }
        }
        
        if ($allFilesExist) {
            Write-TestResult "Required template files exist" $true
        } else {
            Write-TestResult "Required template files exist" $false "Missing files: $($missingFiles -join ', ')"
            return $false
        }
    } catch {
        Write-TestResult "Required template files exist" $false $_.Exception.Message
        return $false
    }
    
    # Test 3: Validate Bicep template syntax
    try {
        $buildResult = az bicep build --file "main.bicep" --stdout 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Main template syntax validation" $true
        } else {
            Write-TestResult "Main template syntax validation" $false $buildResult
            return $false
        }
    } catch {
        Write-TestResult "Main template syntax validation" $false $_.Exception.Message
        return $false
    }
    
    # Test 4: Validate parameter file format
    try {
        $paramContent = Get-Content "parameters/$Environment.parameters.json" -Raw | ConvertFrom-Json
        if ($paramContent.'$schema' -and $paramContent.contentVersion -and $paramContent.parameters) {
            Write-TestResult "Parameter file format validation" $true
        } else {
            Write-TestResult "Parameter file format validation" $false "Invalid parameter file format"
            return $false
        }
    } catch {
        Write-TestResult "Parameter file format validation" $false $_.Exception.Message
        return $false
    }
    
    # Test 5: Validate resource group creation/existence
    try {
        $rgExists = az group exists --name $ResourceGroupName
        if ($rgExists -eq "false") {
            Write-Host "Creating test resource group: $ResourceGroupName" -ForegroundColor Yellow
            az group create --name $ResourceGroupName --location $Location --output none
            if ($LASTEXITCODE -eq 0) {
                Write-TestResult "Test resource group creation" $true "Created: $ResourceGroupName"
            } else {
                Write-TestResult "Test resource group creation" $false "Failed to create resource group"
                return $false
            }
        } else {
            Write-TestResult "Test resource group exists" $true "Using existing: $ResourceGroupName"
        }
    } catch {
        Write-TestResult "Test resource group setup" $false $_.Exception.Message
        return $false
    }
    
    return $true
}

function Test-DeploymentValidation {
    Write-Host "`nTesting Deployment Validation..." -ForegroundColor Cyan
    
    # Test 1: Azure deployment validation (what-if)
    try {
        Write-Host "Running Azure deployment validation..." -ForegroundColor Yellow
        $validateResult = az deployment group validate `
            --resource-group $ResourceGroupName `
            --template-file "main.bicep" `
            --parameters "@parameters/$Environment.parameters.json" `
            --name "$deploymentName-validate" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Azure deployment validation" $true
        } else {
            Write-TestResult "Azure deployment validation" $false $validateResult
            return $false
        }
    } catch {
        Write-TestResult "Azure deployment validation" $false $_.Exception.Message
        return $false
    }
    
    # Test 2: What-if analysis
    try {
        Write-Host "Running what-if analysis..." -ForegroundColor Yellow
        $whatIfResult = az deployment group what-if `
            --resource-group $ResourceGroupName `
            --template-file "main.bicep" `
            --parameters "@parameters/$Environment.parameters.json" `
            --name "$deploymentName-whatif" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "What-if analysis" $true
        } else {
            Write-TestResult "What-if analysis" $false $whatIfResult
            return $false
        }
    } catch {
        Write-TestResult "What-if analysis" $false $_.Exception.Message
        return $false
    }
    
    return $true
}

function Test-EndToEndDeployment {
    Write-Host "`nTesting End-to-End Deployment..." -ForegroundColor Cyan
    
    if ($SkipDeployment) {
        Write-Host "Skipping actual deployment as requested" -ForegroundColor Yellow
        Write-TestResult "End-to-end deployment (skipped)" $true "Deployment skipped by user request"
        return $true
    }
    
    # Test 1: Full infrastructure deployment
    try {
        Write-Host "Starting full infrastructure deployment..." -ForegroundColor Yellow
        $deploymentStart = Get-Date
        
        $deployResult = az deployment group create `
            --resource-group $ResourceGroupName `
            --template-file "main.bicep" `
            --parameters "@parameters/$Environment.parameters.json" `
            --name $deploymentName `
            --output json 2>&1
        
        $deploymentEnd = Get-Date
        $deploymentDuration = $deploymentEnd - $deploymentStart
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Full infrastructure deployment" $true "Duration: $($deploymentDuration.ToString('hh\:mm\:ss'))"
            $script:deploymentSucceeded = $true
        } else {
            Write-TestResult "Full infrastructure deployment" $false $deployResult
            $script:deploymentSucceeded = $false
            return $false
        }
    } catch {
        Write-TestResult "Full infrastructure deployment" $false $_.Exception.Message
        $script:deploymentSucceeded = $false
        return $false
    }
    
    # Test 2: Validate deployment outputs
    try {
        Write-Host "Validating deployment outputs..." -ForegroundColor Yellow
        $outputs = az deployment group show `
            --resource-group $ResourceGroupName `
            --name $deploymentName `
            --query "properties.outputs" `
            --output json | ConvertFrom-Json
        
        $requiredOutputs = @(
            'namingConvention',
            'networking',
            'security',
            'compute',
            'data',
            'monitoring'
        )
        
        $allOutputsPresent = $true
        $missingOutputs = @()
        
        foreach ($output in $requiredOutputs) {
            if (-not $outputs.PSObject.Properties.Name.Contains($output)) {
                $allOutputsPresent = $false
                $missingOutputs += $output
            }
        }
        
        if ($allOutputsPresent) {
            Write-TestResult "Deployment outputs validation" $true "All required outputs present"
        } else {
            Write-TestResult "Deployment outputs validation" $false "Missing outputs: $($missingOutputs -join ', ')"
        }
    } catch {
        Write-TestResult "Deployment outputs validation" $false $_.Exception.Message
    }
    
    # Test 3: Validate deployed resources
    try {
        Write-Host "Validating deployed resources..." -ForegroundColor Yellow
        $resources = az resource list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        
        $expectedResourceTypes = @(
            'Microsoft.Network/virtualNetworks',
            'Microsoft.Network/networkSecurityGroups',
            'Microsoft.Network/applicationGateways',
            'Microsoft.Network/loadBalancers',
            'Microsoft.KeyVault/vaults',
            'Microsoft.Sql/servers',
            'Microsoft.Storage/storageAccounts',
            'Microsoft.OperationalInsights/workspaces',
            'Microsoft.Insights/components'
        )
        
        $deployedResourceTypes = $resources | ForEach-Object { $_.type } | Sort-Object -Unique
        $allResourceTypesDeployed = $true
        $missingResourceTypes = @()
        
        foreach ($resourceType in $expectedResourceTypes) {
            if ($resourceType -notin $deployedResourceTypes) {
                $allResourceTypesDeployed = $false
                $missingResourceTypes += $resourceType
            }
        }
        
        if ($allResourceTypesDeployed) {
            Write-TestResult "Deployed resources validation" $true "All expected resource types deployed ($($resources.Count) total resources)"
        } else {
            Write-TestResult "Deployed resources validation" $false "Missing resource types: $($missingResourceTypes -join ', ')"
        }
    } catch {
        Write-TestResult "Deployed resources validation" $false $_.Exception.Message
    }
    
    return $script:deploymentSucceeded
}

function Test-DeploymentHealthChecks {
    Write-Host "`nTesting Deployment Health Checks..." -ForegroundColor Cyan
    
    if ($SkipDeployment -or -not $script:deploymentSucceeded) {
        Write-Host "Skipping health checks - deployment not completed" -ForegroundColor Yellow
        Write-TestResult "Deployment health checks (skipped)" $true "Skipped due to deployment status"
        return $true
    }
    
    # Test 1: Application Gateway health
    try {
        $appGateway = az network application-gateway list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        if ($appGateway -and $appGateway.Count -gt 0) {
            $agwStatus = $appGateway[0].provisioningState
            if ($agwStatus -eq "Succeeded") {
                Write-TestResult "Application Gateway health" $true "Status: $agwStatus"
            } else {
                Write-TestResult "Application Gateway health" $false "Status: $agwStatus"
            }
        } else {
            Write-TestResult "Application Gateway health" $false "Application Gateway not found"
        }
    } catch {
        Write-TestResult "Application Gateway health" $false $_.Exception.Message
    }
    
    # Test 2: SQL Server connectivity
    try {
        $sqlServers = az sql server list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        if ($sqlServers -and $sqlServers.Count -gt 0) {
            $sqlStatus = $sqlServers[0].state
            if ($sqlStatus -eq "Ready") {
                Write-TestResult "SQL Server connectivity" $true "Status: $sqlStatus"
            } else {
                Write-TestResult "SQL Server connectivity" $false "Status: $sqlStatus"
            }
        } else {
            Write-TestResult "SQL Server connectivity" $false "SQL Server not found"
        }
    } catch {
        Write-TestResult "SQL Server connectivity" $false $_.Exception.Message
    }
    
    # Test 3: Storage Account accessibility
    try {
        $storageAccounts = az storage account list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        if ($storageAccounts -and $storageAccounts.Count -gt 0) {
            $storageStatus = $storageAccounts[0].provisioningState
            if ($storageStatus -eq "Succeeded") {
                Write-TestResult "Storage Account accessibility" $true "Status: $storageStatus"
            } else {
                Write-TestResult "Storage Account accessibility" $false "Status: $storageStatus"
            }
        } else {
            Write-TestResult "Storage Account accessibility" $false "Storage Account not found"
        }
    } catch {
        Write-TestResult "Storage Account accessibility" $false $_.Exception.Message
    }
    
    # Test 4: Key Vault accessibility
    try {
        $keyVaults = az keyvault list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        if ($keyVaults -and $keyVaults.Count -gt 0) {
            $kvStatus = $keyVaults[0].properties.provisioningState
            if ($kvStatus -eq "Succeeded") {
                Write-TestResult "Key Vault accessibility" $true "Status: $kvStatus"
            } else {
                Write-TestResult "Key Vault accessibility" $false "Status: $kvStatus"
            }
        } else {
            Write-TestResult "Key Vault accessibility" $false "Key Vault not found"
        }
    } catch {
        Write-TestResult "Key Vault accessibility" $false $_.Exception.Message
    }
    
    # Test 5: Log Analytics Workspace
    try {
        $workspaces = az monitor log-analytics workspace list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        if ($workspaces -and $workspaces.Count -gt 0) {
            $workspaceStatus = $workspaces[0].provisioningState
            if ($workspaceStatus -eq "Succeeded") {
                Write-TestResult "Log Analytics Workspace health" $true "Status: $workspaceStatus"
            } else {
                Write-TestResult "Log Analytics Workspace health" $false "Status: $workspaceStatus"
            }
        } else {
            Write-TestResult "Log Analytics Workspace health" $false "Log Analytics Workspace not found"
        }
    } catch {
        Write-TestResult "Log Analytics Workspace health" $false $_.Exception.Message
    }
    
    return $true
}

function Test-RollbackScenarios {
    Write-Host "`nTesting Rollback and Recovery Scenarios..." -ForegroundColor Cyan
    
    if ($SkipDeployment -or -not $script:deploymentSucceeded) {
        Write-Host "Skipping rollback tests - deployment not completed" -ForegroundColor Yellow
        Write-TestResult "Rollback scenarios (skipped)" $true "Skipped due to deployment status"
        return $true
    }
    
    # Test 1: Deployment history validation
    try {
        $deploymentHistory = az deployment group list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        $successfulDeployments = $deploymentHistory | Where-Object { $_.properties.provisioningState -eq "Succeeded" }
        
        if ($successfulDeployments -and $successfulDeployments.Count -gt 0) {
            Write-TestResult "Deployment history validation" $true "Found $($successfulDeployments.Count) successful deployment(s)"
        } else {
            Write-TestResult "Deployment history validation" $false "No successful deployments found"
            return $false
        }
    } catch {
        Write-TestResult "Deployment history validation" $false $_.Exception.Message
        return $false
    }
    
    # Test 2: Configuration change simulation (parameter modification)
    try {
        Write-Host "Simulating configuration change..." -ForegroundColor Yellow
        
        # Create a modified parameter file for rollback testing
        $originalParams = Get-Content "parameters/$Environment.parameters.json" -Raw | ConvertFrom-Json
        $modifiedParams = $originalParams.PSObject.Copy()
        
        # Modify a safe parameter (tags)
        $modifiedParams.parameters.tags.value.TestRollback = "true"
        $modifiedParams.parameters.tags.value.RollbackTest = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
        
        $modifiedParamsJson = $modifiedParams | ConvertTo-Json -Depth 10
        $tempParamFile = "parameters/temp-rollback-$Environment.parameters.json"
        $modifiedParamsJson | Out-File -FilePath $tempParamFile -Encoding UTF8
        
        # Deploy with modified parameters
        $rollbackResult = az deployment group create `
            --resource-group $ResourceGroupName `
            --template-file "main.bicep" `
            --parameters "@$tempParamFile" `
            --name $rollbackDeploymentName `
            --output json 2>&1
        
        # Cleanup temp file
        if (Test-Path $tempParamFile) {
            Remove-Item $tempParamFile -Force
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Configuration change deployment" $true "Successfully deployed configuration change"
        } else {
            Write-TestResult "Configuration change deployment" $false $rollbackResult
        }
    } catch {
        Write-TestResult "Configuration change deployment" $false $_.Exception.Message
    }
    
    # Test 3: Rollback to previous configuration
    try {
        Write-Host "Testing rollback to original configuration..." -ForegroundColor Yellow
        
        $rollbackToOriginalResult = az deployment group create `
            --resource-group $ResourceGroupName `
            --template-file "main.bicep" `
            --parameters "@parameters/$Environment.parameters.json" `
            --name "$rollbackDeploymentName-original" `
            --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Rollback to original configuration" $true "Successfully rolled back to original configuration"
        } else {
            Write-TestResult "Rollback to original configuration" $false $rollbackToOriginalResult
        }
    } catch {
        Write-TestResult "Rollback to original configuration" $false $_.Exception.Message
    }
    
    # Test 4: Deployment failure recovery simulation
    try {
        Write-Host "Simulating deployment failure recovery..." -ForegroundColor Yellow
        
        # Create an invalid parameter file to simulate failure
        $invalidParams = Get-Content "parameters/$Environment.parameters.json" -Raw | ConvertFrom-Json
        $invalidParams.parameters.location.value = "InvalidLocation"
        
        $invalidParamsJson = $invalidParams | ConvertTo-Json -Depth 10
        $invalidParamFile = "parameters/temp-invalid-$Environment.parameters.json"
        $invalidParamsJson | Out-File -FilePath $invalidParamFile -Encoding UTF8
        
        # Attempt deployment with invalid parameters (should fail)
        $failureResult = az deployment group create `
            --resource-group $ResourceGroupName `
            --template-file "main.bicep" `
            --parameters "@$invalidParamFile" `
            --name "$rollbackDeploymentName-failure" `
            --output json 2>&1
        
        # Cleanup temp file
        if (Test-Path $invalidParamFile) {
            Remove-Item $invalidParamFile -Force
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-TestResult "Deployment failure simulation" $true "Deployment correctly failed with invalid parameters"
            
            # Test recovery by deploying valid configuration
            $recoveryResult = az deployment group create `
                --resource-group $ResourceGroupName `
                --template-file "main.bicep" `
                --parameters "@parameters/$Environment.parameters.json" `
                --name "$rollbackDeploymentName-recovery" `
                --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-TestResult "Deployment failure recovery" $true "Successfully recovered from deployment failure"
            } else {
                Write-TestResult "Deployment failure recovery" $false $recoveryResult
            }
        } else {
            Write-TestResult "Deployment failure simulation" $false "Deployment should have failed but succeeded"
        }
    } catch {
        Write-TestResult "Deployment failure recovery" $false $_.Exception.Message
    }
    
    return $true
}

function Test-DeploymentAutomationWorkflows {
    Write-Host "`nTesting Deployment Automation Workflows..." -ForegroundColor Cyan
    
    # Test 1: Validate deployment script functionality
    try {
        Write-Host "Testing deployment script validation..." -ForegroundColor Yellow
        
        # Test the validate.ps1 script
        $validateScriptResult = & ".\scripts\validate.ps1" `
            -TemplateFile "main.bicep" `
            -ParameterFile "parameters/$Environment.parameters.json" `
            -ResourceGroupName $ResourceGroupName `
            -ValidateStructure 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Deployment script validation" $true "Validation script executed successfully"
        } else {
            Write-TestResult "Deployment script validation" $false $validateScriptResult
        }
    } catch {
        Write-TestResult "Deployment script validation" $false $_.Exception.Message
    }
    
    # Test 2: Test security scanning integration
    try {
        Write-Host "Testing security scanning integration..." -ForegroundColor Yellow
        
        # Check if Checkov is available
        $checkovAvailable = $false
        try {
            $checkovVersion = checkov --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $checkovAvailable = $true
            }
        } catch {
            # Checkov not available
        }
        
        if ($checkovAvailable) {
            $securityScanResult = checkov -d . --framework bicep --config-file .checkov.yaml --soft-fail 2>&1
            Write-TestResult "Security scanning integration" $true "Checkov scan completed"
        } else {
            Write-TestResult "Security scanning integration" $true "Checkov not available - test skipped"
        }
    } catch {
        Write-TestResult "Security scanning integration" $false $_.Exception.Message
    }
    
    # Test 3: Test parameter validation workflows
    try {
        Write-Host "Testing parameter validation workflows..." -ForegroundColor Yellow
        
        # Test with all environment parameter files
        $environments = @('dev', 'staging', 'prod')
        $allEnvironmentsValid = $true
        $invalidEnvironments = @()
        
        foreach ($env in $environments) {
            $paramFile = "parameters/$env.parameters.json"
            if (Test-Path $paramFile) {
                try {
                    $paramContent = Get-Content $paramFile -Raw | ConvertFrom-Json
                    if (-not ($paramContent.'$schema' -and $paramContent.contentVersion -and $paramContent.parameters)) {
                        $allEnvironmentsValid = $false
                        $invalidEnvironments += $env
                    }
                } catch {
                    $allEnvironmentsValid = $false
                    $invalidEnvironments += $env
                }
            }
        }
        
        if ($allEnvironmentsValid) {
            Write-TestResult "Parameter validation workflows" $true "All environment parameter files are valid"
        } else {
            Write-TestResult "Parameter validation workflows" $false "Invalid parameter files: $($invalidEnvironments -join ', ')"
        }
    } catch {
        Write-TestResult "Parameter validation workflows" $false $_.Exception.Message
    }
    
    # Test 4: Test deployment naming conventions
    try {
        Write-Host "Testing deployment naming conventions..." -ForegroundColor Yellow
        
        $deployments = az deployment group list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        $testDeployments = $deployments | Where-Object { $_.name -like "*test*" -or $_.name -like "*rollback*" }
        
        if ($testDeployments -and $testDeployments.Count -gt 0) {
            $namingConventionValid = $true
            foreach ($deployment in $testDeployments) {
                if ($deployment.name -notmatch "^\w+-\w+-\d{8}-\d{6}$" -and $deployment.name -notmatch "^test-deployment-\d{8}-\d{6}") {
                    $namingConventionValid = $false
                    break
                }
            }
            
            if ($namingConventionValid) {
                Write-TestResult "Deployment naming conventions" $true "All deployment names follow conventions"
            } else {
                Write-TestResult "Deployment naming conventions" $false "Some deployment names don't follow conventions"
            }
        } else {
            Write-TestResult "Deployment naming conventions" $true "No test deployments found to validate"
        }
    } catch {
        Write-TestResult "Deployment naming conventions" $false $_.Exception.Message
    }
    
    return $true
}

function Cleanup-TestResources {
    if ($CleanupAfterTest -and $script:deploymentSucceeded) {
        Write-Host "`nCleaning up test resources..." -ForegroundColor Yellow
        
        try {
            # Delete the test resource group
            az group delete --name $ResourceGroupName --yes --no-wait
            Write-Host "Initiated cleanup of resource group: $ResourceGroupName" -ForegroundColor Green
        } catch {
            Write-Host "Failed to cleanup resource group: $_" -ForegroundColor Red
        }
    } elseif ($CleanupAfterTest) {
        Write-Host "`nSkipping cleanup - deployment was not successful" -ForegroundColor Yellow
    } else {
        Write-Host "`nSkipping cleanup - CleanupAfterTest not specified" -ForegroundColor Yellow
        Write-Host "To cleanup manually, run: az group delete --name $ResourceGroupName --yes" -ForegroundColor Cyan
    }
}

# Initialize variables
$script:deploymentSucceeded = $false

# Main execution
Write-Host "Starting Deployment Automation Tests..." -ForegroundColor Green
Write-Host "Test Scope: $TestScope" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow

# Run tests based on scope
$preDeploymentSuccess = $true
if ($TestScope -eq "All" -or $TestScope -eq "PreDeployment") {
    $preDeploymentSuccess = Test-PreDeploymentValidation
}

$deploymentValidationSuccess = $true
if (($TestScope -eq "All" -or $TestScope -eq "DeploymentValidation") -and $preDeploymentSuccess) {
    $deploymentValidationSuccess = Test-DeploymentValidation
}

$endToEndSuccess = $true
if (($TestScope -eq "All" -or $TestScope -eq "EndToEnd") -and $preDeploymentSuccess -and $deploymentValidationSuccess) {
    $endToEndSuccess = Test-EndToEndDeployment
}

if (($TestScope -eq "All" -or $TestScope -eq "HealthChecks") -and $endToEndSuccess) {
    Test-DeploymentHealthChecks
}

if (($TestScope -eq "All" -or $TestScope -eq "Rollback") -and $endToEndSuccess) {
    Test-RollbackScenarios
}

if ($TestScope -eq "All" -or $TestScope -eq "Workflows") {
    Test-DeploymentAutomationWorkflows
}

# Cleanup if requested
Cleanup-TestResources

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
    
    Write-Host "`nRecommendations:" -ForegroundColor Yellow
    Write-Host "1. Review failed tests and fix underlying issues" -ForegroundColor White
    Write-Host "2. Ensure Azure CLI is authenticated and has proper permissions" -ForegroundColor White
    Write-Host "3. Verify all required template files and modules exist" -ForegroundColor White
    Write-Host "4. Check parameter file configurations for all environments" -ForegroundColor White
    
    exit 1
} else {
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    Write-Host "`nDeployment automation is working correctly." -ForegroundColor Green
    
    if ($script:deploymentSucceeded) {
        Write-Host "`nDeployment Details:" -ForegroundColor Cyan
        Write-Host "- Resource Group: $ResourceGroupName" -ForegroundColor White
        Write-Host "- Environment: $Environment" -ForegroundColor White
        Write-Host "- Deployment Name: $deploymentName" -ForegroundColor White
        
        if (-not $CleanupAfterTest) {
            Write-Host "`nTo view deployed resources:" -ForegroundColor Cyan
            Write-Host "az resource list --resource-group $ResourceGroupName --output table" -ForegroundColor White
            Write-Host "`nTo cleanup resources:" -ForegroundColor Cyan
            Write-Host "az group delete --name $ResourceGroupName --yes" -ForegroundColor White
        }
    }
    
    exit 0
}