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
│   │   ├── vnet-manager.bicep # Virtual Network Manager configuration
│   │   ├── virtual-network.bicep # Virtual networks and subnets
│   │   ├── network-security-groups.bicep # NSG rules and associations
│   │   ├── ddos-protection.bicep # DDoS protection plans
│   │   └── public-ip.bicep    # Public IP addresses for Application Gateway
│   ├── security/              # Security and identity modules
│   ├── compute/               # Compute and load balancing modules
│   ├── data/                  # Database and storage modules
│   └── monitoring/            # Logging and monitoring modules
├── scripts/                   # Deployment and validation scripts
│   ├── deploy.ps1             # Main deployment script
│   ├── validate.ps1           # Template validation script
│   ├── security-scan.ps1      # Checkov security scanning script
│   └── test-compute-modules.ps1 # Compute module unit tests
├── .checkov.yaml              # Checkov configuration file
└── .checkovignore             # Checkov ignore patterns
```

## Key Features

- **Modular Architecture**: Reusable Bicep modules for networking, security, compute, and data components
- **Multi-Environment Support**: Separate configurations for dev, staging, and production environments
- **Security-First Design**: Defense-in-depth security with WAF, NSGs, private endpoints, and DDoS protection
- **Automated Security Scanning**: Integrated Checkov scanning for continuous security validation and compliance
- **High Availability**: Multi-zone deployment with load balancing and automated failover
- **Centralized Network Management**: Azure Virtual Network Manager for unified network governance and security policies
- **Comprehensive Networking**: Virtual networks with segmented subnets, NSGs, and service endpoints
- **Environment-Specific Configuration**: Optimized settings for development, staging, and production workloads

## Getting Started

### Prerequisites

- Azure CLI with Bicep extension
- PowerShell 5.1 or later
- Checkov (for security scanning)
- Appropriate Azure permissions

### Deployment

1. **Create Resource Group**:
   ```powershell
   az group create --name contoso-webapp-dev-rg --location "East US"
   ```

2. **Validate templates**:
   ```powershell
   .\scripts\validate.ps1 -TemplateFile main.bicep -ParameterFile parameters\dev.parameters.json -ResourceGroupName contoso-webapp-dev-rg
   ```

3. **Run security scan**:
   ```powershell
   checkov -d . --framework bicep --config-file .checkov.yaml
   ```

4. **Test compute modules** (optional):
   ```powershell
   # Test all compute modules
   .\scripts\test-compute-modules.ps1
   
   # Test specific module with verbose output
   .\scripts\test-compute-modules.ps1 -TestScope ApplicationGateway -VerboseOutput
   
   # Test for specific environment
   .\scripts\test-compute-modules.ps1 -Environment staging -VerboseOutput
   ```

5. **Deploy infrastructure**:
   ```powershell
   # Development environment
   az deployment group create --resource-group contoso-webapp-dev-rg --template-file main.bicep --parameters @parameters/dev.parameters.json

   # Staging environment  
   az deployment group create --resource-group contoso-webapp-staging-rg --template-file main.bicep --parameters @parameters/staging.parameters.json

   # Production environment (with what-if preview)
   az deployment group create --resource-group contoso-webapp-prod-rg --template-file main.bicep --parameters @parameters/prod.parameters.json --confirm-with-what-if
   ```

6. **Verify deployment**:
   ```powershell
   # Check resource deployment status
   az deployment group show --resource-group contoso-webapp-dev-rg --name main

   # List deployed resources
   az resource list --resource-group contoso-webapp-dev-rg --output table
   ```

## Architecture Overview

The infrastructure implements a secure multi-tier architecture with the following components:

### Network Architecture
- **Virtual Network Manager**: Centralized network governance with network groups and security policies
- **Segmented Subnets**: Application Gateway, Management, Web Tier, Business Tier, Data Tier, and Active Directory subnets
- **Network Security Groups**: Tier-specific security rules following principle of least privilege
- **Public IP Addresses**: Standard SKU public IPs with zone redundancy for Application Gateway and other public-facing resources
- **DDoS Protection**: Enhanced protection for public-facing resources (staging and production)
- **Service Endpoints**: Secure connectivity to Azure services (Key Vault, Storage, SQL)

### Environment Configuration

Each environment has specific configurations optimized for its purpose:

- **Development**: 
  - Minimal resources (Basic SKUs, single instances)
  - Cost-optimized settings (Standard_LRS storage, no DDoS protection)
  - Basic security (no private endpoints)
  - Network: 10.0.0.0/16 address space

- **Staging**: 
  - Production-like deployment (Standard SKUs, 2 instances)
  - Enhanced security (DDoS protection, private endpoints enabled)
  - Extended monitoring (90-day log retention)
  - Network: 10.1.0.0/16 address space

- **Production**: 
  - High availability (Premium SKUs, 3 instances across zones)
  - Maximum security (WAF_v2, DDoS protection, private endpoints)
  - Comprehensive monitoring (365-day log retention)
  - Network: 10.2.0.0/16 address space

## Module Usage Examples

### Public IP Module

The Public IP module creates Standard SKU public IP addresses for Application Gateway and other public-facing resources:

```bicep
module applicationGatewayPublicIp 'modules/networking/public-ip.bicep' = {
  name: 'application-gateway-public-ip-deployment'
  params: {
    publicIpName: 'contoso-webapp-prod-agw-pip'
    sku: 'Standard'
    allocationMethod: 'Static'
    domainNameLabel: 'contoso-webapp-prod-agw'
    zones: ['1', '2', '3'] // Zone redundancy for high availability
    tags: {
      Environment: 'prod'
      Workload: 'webapp'
      Purpose: 'ApplicationGateway'
    }
    location: 'East US'
  }
}
```

#### Public IP Configuration Options

- **SKU**: `Basic` or `Standard` (Standard recommended for production)
- **Allocation Method**: `Static` (recommended) or `Dynamic`
- **Zone Redundancy**: Availability zones for Standard SKU (enhances availability)
- **DNS Integration**: Optional domain name label for friendly DNS names
- **IP Version**: IPv4 (default) or IPv6 support

### Key Vault Module

The Key Vault module provides secure secret management with comprehensive security controls:

```bicep
module keyVault 'modules/security/key-vault.bicep' = {
  name: 'key-vault-deployment'
  params: {
    keyVaultName: 'contoso-webapp-prod-kv'
    location: 'East US'
    tags: {
      Environment: 'prod'
      Workload: 'webapp'
      ManagedBy: 'Bicep'
    }
    keyVaultConfig: {
      sku: 'premium'
      enableSoftDelete: true
      softDeleteRetentionInDays: 90
      enablePurgeProtection: true
      enableRbacAuthorization: true
      networkAcls: {
        bypass: 'AzureServices'
        defaultAction: 'Deny'
        ipRules: []
        virtualNetworkRules: []
      }
    }
    allowedSubnetIds: [
      '/subscriptions/.../subnets/web-tier-subnet'
      '/subscriptions/.../subnets/business-tier-subnet'
    ]
    keyVaultAdministrators: [
      'user-object-id-1'
      'user-object-id-2'
    ]
    keyVaultSecretsUsers: [
      'managed-identity-object-id'
    ]
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/law-workspace'
  }
}
```

#### Key Vault Configuration Options

- **SKU**: `standard` (default) or `premium` (for HSM-backed keys)
- **Soft Delete**: Configurable retention period (7-90 days)
- **Network Access**: Support for subnet restrictions and IP allowlists
- **RBAC Roles**: Built-in role assignments for administrators and service accounts
- **Monitoring**: Optional diagnostic settings integration with Log Analytics

## Security Features

### Network Security
- **Network Segmentation**: Separate subnets for each application tier with dedicated NSGs
- **Network Security Groups**: Comprehensive rules following principle of least privilege
  - Application Gateway: Allows HTTP/HTTPS from internet, blocks direct access
  - Management: Restricted RDP/SSH access from management subnet only
  - Web Tier: Accepts traffic from Application Gateway, communicates with Business Tier
  - Business Tier: Accepts traffic from Web Tier, communicates with Data Tier
  - Data Tier: Accepts database traffic from Business Tier, no internet access
  - Active Directory: LDAP/Kerberos/DNS access from VNet, management access only
- **DDoS Protection**: Standard DDoS protection for public-facing resources (enabled in staging/production)
- **Virtual Network Manager**: Centralized security admin rules blocking high-risk ports (RDP/SSH) from internet

### Service Security
- **Key Vault Integration**: Centralized secret management with RBAC and network restrictions
  - Soft delete and purge protection for production environments
  - Network access controls with subnet and IP restrictions
  - Built-in role assignments for secure access management
  - Comprehensive audit logging and diagnostic monitoring
- **Private Endpoints**: Secure connectivity for data services (enabled in staging/production)
- **Service Endpoints**: Secure access to Key Vault, Storage, and SQL services from subnets
- **Web Application Firewall**: OWASP Core Rule Set protection (WAF_v2 in production)
- **Managed Identities**: Service-to-service authentication without stored credentials

### Data Protection
- **Encryption**: All data encrypted at rest and in transit
- **Key Vault Security**: 
  - Centralized secret and certificate management with RBAC authorization
  - Network access controls with subnet restrictions and IP allowlists
  - Soft delete protection with configurable retention periods
  - Purge protection for production environments to prevent accidental deletion
  - HSM-backed keys available with Premium SKU
- **Access Controls**: RBAC and network-based access restrictions
- **Audit Logging**: Comprehensive logging for security events and administrative operations

## Testing

### Compute Module Testing

The project includes comprehensive unit tests for compute modules to validate configuration and functionality:

#### Test Script Usage

```powershell
# Test all compute modules
.\scripts\test-compute-modules.ps1

# Test specific module
.\scripts\test-compute-modules.ps1 -TestScope ApplicationGateway
.\scripts\test-compute-modules.ps1 -TestScope LoadBalancer
.\scripts\test-compute-modules.ps1 -TestScope VirtualMachine
.\scripts\test-compute-modules.ps1 -TestScope AvailabilitySet

# Test with verbose output for detailed information
.\scripts\test-compute-modules.ps1 -VerboseOutput

# Test for specific environment
.\scripts\test-compute-modules.ps1 -Environment staging -VerboseOutput
```

#### Test Coverage

The test script validates the following aspects of compute modules:

**Application Gateway Module Tests:**
- Template syntax validation using `az bicep build`
- Required parameter validation (applicationGatewayName, subnetId, publicIpAddressId)
- WAF configuration and policy validation
- SSL certificate support with Key Vault integration
- Health probe configuration for backend monitoring
- Backend pool management and routing rules

**Load Balancer Module Tests:**
- Template syntax validation
- Required parameter validation (loadBalancerName, subnetId, tier)
- Health probe functionality for HTTP/HTTPS and TCP protocols
- Load balancing rules configuration
- Tier-specific configuration validation (business/data tiers)
- Availability zone support for Standard SKU

**Virtual Machine Module Tests:**
- Template syntax validation
- Availability zone deployment configuration
- Autoscaling configuration with CPU metrics and scale rules

**Availability Set Module Tests:**
- Template syntax validation
- Fault domain and update domain configuration

#### Test Results

The test script provides comprehensive output including:
- ✓ Passed tests (displayed in green)
- ✗ Failed tests with detailed error messages (displayed in red)
- Test summary with total, passed, and failed counts
- Detailed failure information when using `-VerboseOutput` parameter

#### Integration with CI/CD

The test script is designed to integrate with CI/CD pipelines:
- Returns exit code 0 for success, 1 for failure
- Supports automated testing in build pipelines
- Provides structured output for parsing by automation tools

## Deployed Infrastructure Components

The main template currently deploys the following infrastructure components:

### Virtual Network Manager
- **Network Groups**: Environment-specific groupings (dev/staging/prod for web, business, data tiers)
- **Connectivity Configurations**: Hub-and-spoke topology setup for each environment
- **Security Admin Rules**: Centralized policies blocking RDP (3389) and SSH (22) from internet

### Virtual Network and Subnets
- **Application Gateway Subnet**: Dedicated subnet for Application Gateway with Key Vault and Storage service endpoints
- **Management Subnet**: Administrative access subnet with comprehensive service endpoints
- **Web Tier Subnet**: Frontend application servers with service endpoints for Key Vault, Storage, and SQL
- **Business Tier Subnet**: Application logic servers with service endpoints for Key Vault, Storage, and SQL  
- **Data Tier Subnet**: Database servers with service endpoints for Key Vault, Storage, and SQL
- **Active Directory Subnet**: Domain services subnet with Key Vault and Storage service endpoints, AAD Domain Services delegation

### Network Security Groups
- **Comprehensive Rule Sets**: Each subnet has dedicated NSG with tier-appropriate security rules
- **Least Privilege Access**: Rules follow security best practices with minimal required access
- **Management Access**: Controlled RDP/SSH access from management subnet to all tiers
- **Application Flow**: Proper traffic flow between tiers (AGW → Web → Business → Data)

### Public IP Addresses
- **Standard SKU**: Zone-redundant public IP addresses for high availability
- **Static Allocation**: Consistent IP addresses for Application Gateway and load balancers
- **DNS Integration**: Configurable domain name labels for friendly DNS names
- **Zone Redundancy**: Multi-zone deployment for enhanced availability (when high availability is enabled)

### DDoS Protection
- **Conditional Deployment**: Enabled for staging and production environments
- **Enhanced Protection**: Standard DDoS protection plan for public-facing resources
- **Monitoring Integration**: Diagnostic settings for DDoS protection telemetry

### Security Infrastructure

#### Key Vault Module
- **Secure Secret Management**: Centralized storage for secrets, keys, and certificates
- **RBAC Authorization**: Role-based access control with built-in Azure roles
  - Key Vault Administrator: Full management permissions
  - Key Vault Secrets User: Read access to secrets for applications
  - Key Vault Certificate User: Certificate management for SSL/TLS
- **Network Security**: Private network access with subnet and IP restrictions
- **Compliance Features**: 
  - Soft delete with configurable retention (7-90 days)
  - Purge protection for production environments
  - Comprehensive audit logging and monitoring
- **Integration Ready**: Diagnostic settings for Log Analytics workspace integration

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

## Deployment Guide

### Prerequisites Checklist

- [ ] Azure CLI installed and updated (`az --version`)
- [ ] Bicep extension installed (`az bicep install`)
- [ ] PowerShell 5.1+ or PowerShell Core 7+
- [ ] Python 3.7+ and Checkov installed (`pip install checkov`)
- [ ] Azure subscription with appropriate permissions (Contributor role)
- [ ] Resource group created for deployment

### Step-by-Step Deployment

1. **Clone and Setup**:
   ```bash
   git clone <repository-url>
   cd azure-bicep-infrastructure
   ```

2. **Login to Azure**:
   ```powershell
   az login
   az account set --subscription <subscription-id>
   ```

3. **Customize Parameters** (optional):
   Edit the parameter files in `parameters/` directory to match your requirements:
   - `dev.parameters.json` - Development environment settings
   - `staging.parameters.json` - Staging environment settings  
   - `prod.parameters.json` - Production environment settings

4. **Validate Templates**:
   ```powershell
   # Validate Bicep syntax
   az bicep build --file main.bicep
   
   # Validate deployment (dry-run)
   az deployment group validate --resource-group contoso-webapp-dev-rg --template-file main.bicep --parameters @parameters/dev.parameters.json
   ```

5. **Security Scan**:
   ```powershell
   checkov -d . --framework bicep --config-file .checkov.yaml
   ```

6. **Deploy Infrastructure**:
   ```powershell
   # Development deployment
   az deployment group create \
     --resource-group contoso-webapp-dev-rg \
     --template-file main.bicep \
     --parameters @parameters/dev.parameters.json \
     --name "networking-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
   ```

7. **Verify Deployment**:
   ```powershell
   # Check deployment status
   az deployment group list --resource-group contoso-webapp-dev-rg --output table
   
   # Verify networking resources
   az network vnet list --resource-group contoso-webapp-dev-rg --output table
   az network nsg list --resource-group contoso-webapp-dev-rg --output table
   
   # Verify public IP addresses
   az network public-ip list --resource-group contoso-webapp-dev-rg --output table
   az network public-ip show --resource-group contoso-webapp-dev-rg --name contoso-webapp-dev-agw-pip --query "{Name:name,IPAddress:ipAddress,AllocationMethod:publicIPAllocationMethod,SKU:sku.name,Zones:zones}"
   
   # Verify Key Vault deployment
   az keyvault list --resource-group contoso-webapp-dev-rg --output table
   az keyvault show --name contoso-webapp-dev-kv --query "properties.{VaultUri:vaultUri,SoftDelete:enableSoftDelete,PurgeProtection:enablePurgeProtection}"
   
   # Verify Application Gateway (when compute modules are deployed)
   az network application-gateway list --resource-group contoso-webapp-dev-rg --output table
   az network application-gateway show --resource-group contoso-webapp-dev-rg --name contoso-webapp-dev-agw --query "{Name:name,State:operationalState,PublicIP:frontendIPConfigurations[0].publicIPAddress.id}"
   ```

### Troubleshooting Common Issues

- **Template Validation Errors**: Check parameter file format and required values
- **Permission Errors**: Ensure you have Contributor role on the subscription/resource group
- **Naming Conflicts**: Verify resource names are unique (especially Key Vault and Storage Account names)
- **Network Address Conflicts**: Ensure VNet address spaces don't overlap with existing networks
- **Test Script Issues**:
  - Ensure Azure CLI is installed and authenticated (`az login`)
  - Verify Bicep extension is installed (`az bicep install`)
  - Check that all module files exist in the expected locations
  - Use `-VerboseOutput` parameter for detailed error information
- **Public IP Issues**:
  - Verify domain name labels are globally unique across Azure
  - Ensure Standard SKU is used for zone redundancy requirements
  - Check that availability zones are supported in the target region
  - Validate that Static allocation is used for Application Gateway requirements
- **Key Vault Access Issues**: 
  - Verify object IDs for role assignments are correct
  - Ensure network access rules allow your deployment source
  - Check that RBAC authorization is enabled if using role assignments
  - Validate subnet IDs if using VNet integration
- **Application Gateway Issues**:
  - Ensure public IP address is Standard SKU and Static allocation
  - Verify SSL certificate is properly stored in Key Vault
  - Check that managed identity has access to Key Vault for certificate retrieval
  - Validate backend pool health probe configurations

## Contributing

This project follows Infrastructure as Code best practices. All changes should be:

1. Validated using the validation scripts
2. Security scanned with Checkov
3. Tested in development environment first
4. Reviewed before production deployment
5. Committed with clear, descriptive messages

## License

This project is licensed under the MIT License - see the LICENSE file for details.