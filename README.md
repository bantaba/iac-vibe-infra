# Azure Bicep Infrastructure Project

This project implements a secure, multi-tier application architecture using Azure Bicep templates with Virtual Network Manager for centralized network governance.

## Project Structure

```
bicep-infrastructure/
├── main.bicep                 # Main orchestration template
├── parameters/                # Environment-specific parameter files
│   ├── dev.parameters.json    # Development environment
│   ├── staging.parameters.json # Staging environment
│   └── prod.parameters.json   # Production environment
├── modules/                   # Reusable Bicep modules
│   ├── networking/            # Network infrastructure modules
│   ├── security/              # Security and identity modules
│   ├── compute/               # Compute and load balancing modules
│   ├── data/                  # Database and storage modules
│   └── monitoring/            # Logging and monitoring modules
├── scripts/                   # Deployment and validation scripts
│   ├── deploy.ps1             # Main deployment script
│   ├── validate.ps1           # Template validation script
│   └── security-scan.ps1      # Checkov security scanning script
├── .checkov.yaml              # Checkov configuration file
└── .checkovignore             # Checkov ignore patterns
```

## Key Features

- **Modular Architecture**: Reusable Bicep modules for different infrastructure components
- **Multi-Environment Support**: Separate configurations for dev, staging, and production
- **Security-First Design**: Defense-in-depth security with WAF, NSGs, and private endpoints
- **Automated Security Scanning**: Integrated Checkov scanning for continuous security validation
- **High Availability**: Multi-zone deployment with load balancing
- **Centralized Management**: Azure Virtual Network Manager for unified network governance

## Getting Started

### Prerequisites

- Azure CLI with Bicep extension
- PowerShell 5.1 or later
- Checkov (for security scanning)
- Appropriate Azure permissions

### Deployment

1. **Validate templates**:
   ```powershell
   .\scripts\validate.ps1 -TemplateFile main.bicep -ParameterFile parameters\dev.parameters.json -ResourceGroupName myapp-dev-rg
   ```

2. **Run security scan**:
   ```powershell
   .\scripts\security-scan.ps1 -Directory . -OutputFormat cli
   ```

3. **Deploy infrastructure**:
   ```powershell
   .\scripts\deploy.ps1 -Environment dev -ResourceGroupName myapp-dev-rg -Location "East US"
   ```

## Environment Configuration

Each environment has specific configurations optimized for its purpose:

- **Development**: Minimal resources, cost-optimized, basic security
- **Staging**: Full-scale deployment matching production for testing
- **Production**: High availability, premium SKUs, comprehensive security

## Security Features

- Network segmentation with NSGs
- Private endpoints for data services
- DDoS protection for public resources
- Web Application Firewall (WAF)
- Centralized secret management with Key Vault
- Comprehensive logging and monitoring

## Git Repository

This project is version controlled with Git. The repository includes:

- **Comprehensive .gitignore**: Excludes build artifacts, secrets, and temporary files
- **Structured commits**: Clear commit messages documenting infrastructure changes
- **Branch protection**: Recommended to use feature branches for changes

### Git Workflow

1. **Create feature branch**: `git checkout -b feature/new-module`
2. **Make changes**: Edit Bicep templates and configurations
3. **Validate changes**: Run validation and security scripts
4. **Commit changes**: `git commit -m "descriptive message"`
5. **Push and review**: Create pull request for review

## Contributing

This project follows Infrastructure as Code best practices. All changes should be:

1. Validated using the validation scripts
2. Security scanned with Checkov
3. Tested in development environment first
4. Reviewed before production deployment
5. Committed with clear, descriptive messages

## License

This project is licensed under the MIT License - see the LICENSE file for details.