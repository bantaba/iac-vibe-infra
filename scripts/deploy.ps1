# Deployment script for Azure Bicep Infrastructure
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$TemplateFile = "main.bicep",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSecurityScan
)

$ErrorActionPreference = "Stop"
$ParameterFile = "parameters/$Environment.parameters.json"
$DeploymentName = "bicep-infrastructure-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "Starting deployment for $Environment environment..." -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "Location: $Location" -ForegroundColor Cyan
Write-Host "Template: $TemplateFile" -ForegroundColor Cyan
Write-Host "Parameters: $ParameterFile" -ForegroundColor Cyan

try {
    # Check if parameter file exists
    if (!(Test-Path $ParameterFile)) {
        throw "Parameter file not found: $ParameterFile"
    }
    
    # Check if template file exists
    if (!(Test-Path $TemplateFile)) {
        throw "Template file not found: $TemplateFile"
    }
    
    # Validate Azure CLI authentication
    Write-Host "Checking Azure CLI authentication..." -ForegroundColor Yellow
    $account = az account show 2>&1 | ConvertFrom-Json
    if (!$account) {
        throw "Not logged in to Azure CLI. Please run 'az login' first."
    }
    Write-Host "Authenticated as: $($account.user.name)" -ForegroundColor Green
    Write-Host "Subscription: $($account.name) ($($account.id))" -ForegroundColor Green
    
    # Check if resource group exists, create if it doesn't
    Write-Host "Checking resource group..." -ForegroundColor Yellow
    $rgExists = az group exists --name $ResourceGroupName
    if ($rgExists -eq "false") {
        Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
        az group create --name $ResourceGroupName --location $Location
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create resource group"
        }
        Write-Host "Resource group created successfully" -ForegroundColor Green
    } else {
        Write-Host "Resource group exists" -ForegroundColor Green
    }
    
    # Run validation if not skipped
    if (!$SkipValidation) {
        Write-Host "Running template validation..." -ForegroundColor Yellow
        & ".\scripts\validate.ps1" -TemplateFile $TemplateFile -ParameterFile $ParameterFile -ResourceGroupName $ResourceGroupName
        if ($LASTEXITCODE -ne 0) {
            throw "Template validation failed"
        }
    }
    
    # Run security scan if not skipped
    if (!$SkipSecurityScan) {
        Write-Host "Running security scan..." -ForegroundColor Yellow
        try {
            checkov -d . --framework bicep --config-file .checkov.yaml --soft-fail
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Security scan found issues. Review the output above."
                $continue = Read-Host "Continue with deployment? (y/N)"
                if ($continue -ne 'y' -and $continue -ne 'Y') {
                    throw "Deployment cancelled due to security scan results"
                }
            }
        } catch {
            Write-Warning "Could not run security scan: $_"
            Write-Host "Ensure Checkov is installed: pip install checkov" -ForegroundColor Yellow
        }
    }
    
    # Run what-if analysis if requested
    if ($WhatIf) {
        Write-Host "Running what-if analysis..." -ForegroundColor Yellow
        az deployment group what-if `
            --resource-group $ResourceGroupName `
            --template-file $TemplateFile `
            --parameters "@$ParameterFile" `
            --name $DeploymentName
        
        if ($LASTEXITCODE -ne 0) {
            throw "What-if analysis failed"
        }
        
        $continue = Read-Host "Proceed with deployment? (y/N)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            Write-Host "Deployment cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Deploy the infrastructure
    Write-Host "Starting deployment: $DeploymentName" -ForegroundColor Green
    $deploymentStart = Get-Date
    
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file $TemplateFile `
        --parameters "@$ParameterFile" `
        --name $DeploymentName `
        --verbose
    
    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed"
    }
    
    $deploymentEnd = Get-Date
    $deploymentDuration = $deploymentEnd - $deploymentStart
    
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Duration: $($deploymentDuration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    
    # Show deployment outputs
    Write-Host "Retrieving deployment outputs..." -ForegroundColor Yellow
    $outputs = az deployment group show `
        --resource-group $ResourceGroupName `
        --name $DeploymentName `
        --query "properties.outputs" `
        --output json | ConvertFrom-Json
    
    if ($outputs) {
        Write-Host "Deployment Outputs:" -ForegroundColor Cyan
        $outputs | ConvertTo-Json -Depth 10 | Write-Host
    }
    
    # List deployed resources
    Write-Host "Deployed resources:" -ForegroundColor Cyan
    az resource list --resource-group $ResourceGroupName --output table
    
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "Deployment failed: $_"
    
    # Show deployment logs if deployment was attempted
    if ($DeploymentName) {
        Write-Host "Checking deployment status..." -ForegroundColor Yellow
        try {
            az deployment group show --resource-group $ResourceGroupName --name $DeploymentName --output table
        } catch {
            Write-Warning "Could not retrieve deployment status"
        }
    }
    
    exit 1
}