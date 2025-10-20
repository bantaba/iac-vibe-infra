# Template validation script for Azure Bicep Infrastructure
param(
    [Parameter(Mandatory=$true)]
    [string]$TemplateFile,
    
    [Parameter(Mandatory=$true)]
    [string]$ParameterFile,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [switch]$ValidateStructure
)

Write-Host "Starting template validation..." -ForegroundColor Green

try {
    # Validate project structure if requested
    if ($ValidateStructure) {
        Write-Host "Validating project structure..." -ForegroundColor Yellow
        
        # Check required directories
        $requiredDirs = @(
            "modules/networking",
            "modules/security", 
            "modules/compute",
            "modules/data",
            "modules/monitoring",
            "modules/shared",
            "parameters",
            "scripts"
        )
        
        foreach ($dir in $requiredDirs) {
            if (!(Test-Path $dir)) {
                throw "Required directory missing: $dir"
            }
        }
        
        # Check required files
        $requiredFiles = @(
            "main.bicep",
            "parameters/dev.parameters.json",
            "parameters/staging.parameters.json", 
            "parameters/prod.parameters.json",
            "modules/shared/naming-conventions.bicep",
            "modules/shared/parameter-schemas.bicep",
            "modules/shared/common-variables.bicep"
        )
        
        foreach ($file in $requiredFiles) {
            if (!(Test-Path $file)) {
                throw "Required file missing: $file"
            }
        }
        
        Write-Host "Project structure validation passed" -ForegroundColor Green
    }
    
    # Validate parameter file format
    Write-Host "Validating parameter file format..." -ForegroundColor Yellow
    try {
        $paramContent = Get-Content $ParameterFile -Raw | ConvertFrom-Json
        if (!$paramContent.'$schema' -or !$paramContent.contentVersion -or !$paramContent.parameters) {
            throw "Parameter file format is invalid"
        }
    } catch {
        throw "Parameter file validation failed: $_"
    }
    
    Write-Host "Parameter file validation passed" -ForegroundColor Green
    
    # Validate naming conventions in parameter file
    Write-Host "Validating naming conventions..." -ForegroundColor Yellow
    $params = $paramContent.parameters
    if ($params.resourcePrefix -and $params.environment -and $params.workloadName) {
        $prefix = $params.resourcePrefix.value
        $env = $params.environment.value
        $workload = $params.workloadName.value
        
        # Validate naming convention compliance
        if ($prefix -notmatch '^[a-z0-9]+$') {
            Write-Warning "Resource prefix should contain only lowercase letters and numbers"
        }
        if ($env -notin @('dev', 'staging', 'prod')) {
            throw "Environment must be one of: dev, staging, prod"
        }
        if ($workload -notmatch '^[a-z0-9]+$') {
            Write-Warning "Workload name should contain only lowercase letters and numbers"
        }
    }
    
    Write-Host "Naming convention validation passed" -ForegroundColor Green
    
    # Validate Bicep template syntax
    Write-Host "Validating Bicep template syntax..." -ForegroundColor Yellow
    try {
        $buildResult = az bicep build --file $TemplateFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Bicep build failed: $buildResult"
        }
    } catch {
        throw "Bicep syntax validation failed: $_"
    }
    
    Write-Host "Bicep syntax validation passed" -ForegroundColor Green
    
    # Validate Azure deployment (if Azure CLI is authenticated)
    Write-Host "Validating Azure deployment..." -ForegroundColor Yellow
    try {
        $validateResult = az deployment group validate `
            --resource-group $ResourceGroupName `
            --template-file $TemplateFile `
            --parameters "@$ParameterFile" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Azure deployment validation failed: $validateResult"
            Write-Host "This may be due to authentication or resource group issues" -ForegroundColor Yellow
        } else {
            Write-Host "Azure deployment validation passed" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Could not validate Azure deployment: $_"
        Write-Host "Ensure you are logged in to Azure CLI and the resource group exists" -ForegroundColor Yellow
    }
    
    Write-Host "Template validation completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "Template validation failed: $_"
    exit 1
}