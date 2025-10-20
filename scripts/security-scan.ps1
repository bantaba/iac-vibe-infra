# Security scanning script using Checkov for Azure Bicep Infrastructure
param(
    [Parameter(Mandatory=$false)]
    [string]$Directory = ".",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('cli', 'json', 'sarif', 'junit', 'github_failed_only')]
    [string]$OutputFormat = "cli",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = ".checkov.yaml",
    
    [Parameter(Mandatory=$false)]
    [switch]$SoftFail,
    
    [Parameter(Mandatory=$false)]
    [switch]$Quiet
)

Write-Host "Starting security scan with Checkov..." -ForegroundColor Green

try {
    # Check if Checkov is installed
    $checkovVersion = checkov --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Checkov is not installed. Please install it using: pip install checkov"
    }
    
    if (!$Quiet) {
        Write-Host "Checkov version: $checkovVersion" -ForegroundColor Cyan
    }
    
    # Check if config file exists
    if ($ConfigFile -and !(Test-Path $ConfigFile)) {
        Write-Warning "Config file not found: $ConfigFile"
        $ConfigFile = ""
    }
    
    # Build Checkov command
    $checkovArgs = @(
        "-d", $Directory,
        "--framework", "bicep"
    )
    
    if ($ConfigFile) {
        $checkovArgs += @("--config-file", $ConfigFile)
    }
    
    $checkovArgs += @("--output", $OutputFormat)
    
    if ($OutputFile) {
        $checkovArgs += @("--output-file-path", $OutputFile)
    }
    
    if ($SoftFail) {
        $checkovArgs += "--soft-fail"
    }
    
    if ($Quiet) {
        $checkovArgs += "--quiet"
    }
    
    # Run Checkov scan
    Write-Host "Running Checkov security scan..." -ForegroundColor Yellow
    Write-Host "Command: checkov $($checkovArgs -join ' ')" -ForegroundColor Gray
    
    & checkov @checkovArgs
    $checkovExitCode = $LASTEXITCODE
    
    # Interpret results
    if ($checkovExitCode -eq 0) {
        Write-Host "Security scan completed successfully - No issues found!" -ForegroundColor Green
    } elseif ($SoftFail -or $checkovExitCode -eq 1) {
        Write-Warning "Security scan found issues. Please review the output above."
        if ($OutputFile) {
            Write-Host "Detailed results saved to: $OutputFile" -ForegroundColor Cyan
        }
        
        if (!$SoftFail) {
            Write-Host "Use -SoftFail parameter to continue despite security issues" -ForegroundColor Yellow
        }
    } else {
        throw "Checkov scan failed with exit code: $checkovExitCode"
    }
    
    # Generate summary report if not quiet
    if (!$Quiet) {
        Write-Host "`nSecurity Scan Summary:" -ForegroundColor Cyan
        Write-Host "- Directory scanned: $Directory" -ForegroundColor Gray
        Write-Host "- Framework: Bicep" -ForegroundColor Gray
        Write-Host "- Output format: $OutputFormat" -ForegroundColor Gray
        if ($OutputFile) {
            Write-Host "- Results file: $OutputFile" -ForegroundColor Gray
        }
        if ($ConfigFile) {
            Write-Host "- Config file: $ConfigFile" -ForegroundColor Gray
        }
    }
    
    exit $checkovExitCode
    
} catch {
    Write-Error "Security scan failed: $_"
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure Checkov is installed: pip install checkov" -ForegroundColor Gray
    Write-Host "2. Ensure Python 3.7+ is installed" -ForegroundColor Gray
    Write-Host "3. Check that Bicep files exist in the specified directory" -ForegroundColor Gray
    exit 1
}