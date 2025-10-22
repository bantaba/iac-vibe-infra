# Technology Stack

## Core Technologies

- **Azure Bicep**: Primary Infrastructure as Code language for Azure resource deployment
- **Azure Resource Manager (ARM)**: Underlying deployment engine for Bicep templates
- **PowerShell**: Deployment automation and validation scripts
- **Azure CLI**: Command-line tooling for Azure operations and Bicep compilation
- **Checkov**: Static analysis tool for Infrastructure as Code security and compliance scanning

## Azure Services

### Networking
- Azure Virtual Network Manager - Centralized network management
- Application Gateway with WAF - Layer 7 load balancing and security
- Load Balancer - Layer 4 traffic distribution
- Network Security Groups - Subnet-level firewall rules
- DDoS Protection - Attack mitigation for public resources

### Security & Identity
- Azure Key Vault - Secret and certificate management
- Managed Identity - Service-to-service authentication
- Azure Active Directory - Identity and access management
- Azure Security Center - Security posture management

### Compute & Storage
- Virtual Machine Scale Sets - Auto-scaling compute resources
- Azure SQL Database - Managed database service
- Storage Accounts - Object storage with private endpoints
- Availability Zones - High availability deployment

### Monitoring
- Log Analytics - Centralized logging and analytics
- Application Insights - Application performance monitoring
- Azure Monitor - Metrics and alerting

## Common Commands

### Development & Validation
```powershell
# Validate Bicep template syntax
az bicep build --file main.bicep

# Validate deployment without executing
az deployment group validate --resource-group myRG --template-file main.bicep --parameters @dev.parameters.json

# Preview changes before deployment
az deployment group what-if --resource-group myRG --template-file main.bicep --parameters @prod.parameters.json
```

### Deployment
```powershell
# Deploy to development environment
az deployment group create --resource-group dev-rg --template-file main.bicep --parameters @parameters/dev.parameters.json

# Deploy to production with confirmation
az deployment group create --resource-group prod-rg --template-file main.bicep --parameters @parameters/prod.parameters.json --confirm-with-what-if
```

### Testing & Validation
```powershell
# Run deployment validation script (subscription-level)
.\scripts\validate.ps1 -TemplateFile main.bicep -ParameterFile parameters\dev.parameters.json -Location "East US"

# Execute full deployment script (subscription-level)
.\scripts\deploy.ps1 -Environment dev -Location "East US"
```

### Security Scanning with Checkov
```powershell
# Install Checkov (requires Python)
pip install checkov

# Scan all Bicep templates for security issues
checkov -d . --framework bicep

# Scan specific template with custom policies
checkov -f main.bicep --framework bicep --config-file .checkov.yaml

# Generate report in multiple formats
checkov -d . --framework bicep --output json --output-file-path checkov-report.json
checkov -d . --framework bicep --output sarif --output-file-path checkov-report.sarif
```

## Build System

The project uses Azure CLI, PowerShell, and Checkov for build automation:
- Template compilation via `az bicep build`
- Parameter validation against schema
- Security scanning with Checkov before deployment
- Pre-deployment validation and what-if analysis
- Automated deployment with error handling and rollback capabilities

### Security Validation Pipeline
1. **Static Analysis**: Checkov scans for security misconfigurations
2. **Template Validation**: Azure CLI validates template syntax and dependencies
3. **Policy Compliance**: Azure Policy validation during deployment
4. **Runtime Security**: Post-deployment security configuration verification