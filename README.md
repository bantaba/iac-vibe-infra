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
│   │   ├── sql-server.bicep   # Azure SQL Database with security features
│   │   ├── storage-account.bicep # Storage accounts with private endpoints
│   │   └── private-endpoints.bicep # Private endpoint configurations
│   └── monitoring/            # Logging and monitoring modules
├── scripts/                   # Deployment and validation scripts
│   ├── deploy.ps1             # Main deployment script
│   ├── validate.ps1           # Template validation script
│   ├── security-scan.ps1      # Checkov security scanning script
│   ├── test-compute-modules.ps1 # Compute module unit tests
│   ├── test-data-layer.ps1    # Data layer module unit tests
│   └── test-private-endpoints.ps1 # Private endpoints module tests
├── .checkov.yaml              # Checkov configuration file
└── .checkovignore             # Checkov ignore patterns
```

## Key Features

- **Modular Architecture**: Reusable Bicep modules for networking, security, compute, and data components
- **Multi-Environment Support**: Separate configurations for dev, staging, and production environments
- **Multi-Cloud Compatibility**: Dynamic DNS resolution and cloud-compatible configurations for Azure Commercial, Government, and China clouds
- **Security-First Design**: Defense-in-depth security with WAF, NSGs, private endpoints, and DDoS protection
- **Automated Security Scanning**: Integrated Checkov scanning for continuous security validation and compliance
- **High Availability**: Multi-zone deployment with load balancing and automated failover
- **Centralized Network Management**: Azure Virtual Network Manager for unified network governance and security policies
- **Comprehensive Networking**: Virtual networks with segmented subnets, NSGs, and service endpoints
- **Environment-Specific Configuration**: Optimized settings for development, staging, and production workloads
- **Secure Data Layer**: Azure SQL Database with private endpoints, encryption, and comprehensive security features
- **Enterprise Storage**: Storage accounts with lifecycle management, private endpoints, and advanced security controls

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

4. **Test modules** (optional):
   ```powershell
   # Test all compute modules
   .\scripts\test-compute-modules.ps1
   
   # Test specific compute module with verbose output
   .\scripts\test-compute-modules.ps1 -TestScope ApplicationGateway -VerboseOutput
   
   # Test all data layer modules (SQL Server, Storage Account, Private Endpoints)
   .\scripts\test-data-layer.ps1
   
   # Test specific data layer module with verbose output
   .\scripts\test-data-layer.ps1 -TestScope SqlServer -VerboseOutput
   .\scripts\test-data-layer.ps1 -TestScope StorageAccount -VerboseOutput
   .\scripts\test-data-layer.ps1 -TestScope PrivateEndpoints -VerboseOutput
   
   # Test private endpoints module
   .\scripts\test-private-endpoints.ps1 -Environment dev -VerboseOutput
   
   # Test private endpoints with validation only (no resource group required)
   .\scripts\test-private-endpoints.ps1 -ValidateOnly -VerboseOutput
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

### Multi-Cloud Compatibility

The infrastructure templates are designed for deployment across different Azure cloud environments:

#### Supported Azure Clouds
- **Azure Commercial**: Standard Azure public cloud (azure.com)
- **Azure Government**: US Government cloud (azure.us) 
- **Azure China**: China-specific cloud (azure.cn)

#### Dynamic Configuration Features
- **DNS Suffix Resolution**: Automatic detection and use of cloud-specific DNS suffixes using Azure `environment()` function
- **Service Endpoint Adaptation**: Dynamic service endpoint configuration based on target cloud environment
- **Private DNS Zone Naming**: Cloud-compatible private DNS zone creation for private endpoints

#### Implementation Details
The templates use Azure's built-in `environment()` function to dynamically resolve cloud-specific configurations:

```bicep
// Example: Cloud-compatible private DNS zone naming
var privateDnsZoneNames = {
  sqlServer: 'privatelink${environment().suffixes.sqlServerHostname}'
  storageBlob: 'privatelink.blob.${environment().suffixes.storage}'
  keyVault: 'privatelink${environment().suffixes.keyvaultDns}'
}
```

This approach ensures:
- **Portability**: Templates work across different Azure clouds without modification
- **Maintainability**: Single template set for all cloud environments
- **Reliability**: Automatic adaptation to cloud-specific service endpoints and DNS suffixes

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

### SQL Server Module

The SQL Server module provides enterprise-grade database services with comprehensive security and monitoring:

```bicep
module sqlServer 'modules/data/sql-server.bicep' = {
  name: 'sql-server-deployment'
  params: {
    sqlServerName: 'contoso-webapp-prod-sql'
    sqlDatabaseName: 'webapp-database'
    location: 'East US'
    tags: {
      Environment: 'prod'
      Workload: 'webapp'
      ManagedBy: 'Bicep'
    }
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'SecurePassword123!' // Should come from Key Vault
    databaseSku: {
      name: 'GP_Gen5_2'
      tier: 'GeneralPurpose'
      capacity: 2
    }
    maxSizeBytes: 1099511627776 // 1TB
    enableAzureAdAuthentication: true
    azureAdAdministratorObjectId: 'admin-group-object-id'
    azureAdAdministratorLogin: 'SQL Administrators'
    enableTransparentDataEncryption: true
    enableAdvancedDataSecurity: true
    enableVulnerabilityAssessment: true
    enablePublicNetworkAccess: false
    allowedSubnetIds: [
      '/subscriptions/.../subnets/data-tier-subnet'
      '/subscriptions/.../subnets/business-tier-subnet'
    ]
    minimalTlsVersion: '1.2'
    backupRetentionDays: 35
    enableGeoRedundantBackup: true
    enableLongTermRetention: true
    longTermRetentionBackup: {
      weeklyRetention: 'P12W'
      monthlyRetention: 'P12M'
      yearlyRetention: 'P7Y'
      weekOfYear: 1
    }
    enableDiagnosticSettings: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/law-workspace'
  }
}
```

#### SQL Server Configuration Options

- **Database SKUs**: Support for Basic, Standard, Premium, and vCore-based options (GP, BC)
- **Security Features**: 
  - Azure AD authentication with group-based administration
  - Transparent Data Encryption (TDE) for data at rest
  - Advanced Data Security (Microsoft Defender for SQL)
  - Vulnerability Assessment with automated scanning
  - Network isolation with private endpoints and firewall rules
- **Backup & Recovery**: 
  - Configurable short-term retention (7-35 days)
  - Long-term retention policies (weekly, monthly, yearly)
  - Geo-redundant backup for disaster recovery
  - Point-in-time restore capabilities
- **Monitoring**: Comprehensive diagnostic settings for audit and performance logs
- **Network Security**: Private network access with subnet restrictions and minimal TLS 1.2

### Storage Account Module

The Storage Account module provides secure, scalable storage with advanced lifecycle management:

```bicep
module storageAccount 'modules/data/storage-account.bicep' = {
  name: 'storage-account-deployment'
  params: {
    storageAccountName: 'contosowebappprodsa'
    location: 'East US'
    tags: {
      Environment: 'prod'
      Workload: 'webapp'
      ManagedBy: 'Bicep'
    }
    storageAccountSku: 'Standard_ZRS'
    storageAccountKind: 'StorageV2'
    accessTier: 'Hot'
    enablePublicNetworkAccess: false
    allowedSubnetIds: [
      '/subscriptions/.../subnets/web-tier-subnet'
      '/subscriptions/.../subnets/business-tier-subnet'
      '/subscriptions/.../subnets/data-tier-subnet'
    ]
    defaultNetworkAccessRule: 'Deny'
    minimumTlsVersion: 'TLS1_2'
    enableHttpsTrafficOnly: true
    enableBlobPublicAccess: false
    enableInfrastructureEncryption: true
    enableBlobVersioning: true
    enableBlobSoftDelete: true
    blobSoftDeleteRetentionDays: 30
    enableLifecycleManagement: true
    lifecycleRules: [
      {
        name: 'production-lifecycle-rule'
        enabled: true
        type: 'Lifecycle'
        definition: {
          filters: {
            blobTypes: ['blockBlob']
          }
          actions: {
            baseBlob: {
              tierToCool: { daysAfterModificationGreaterThan: 30 }
              tierToArchive: { daysAfterModificationGreaterThan: 90 }
              delete: { daysAfterModificationGreaterThan: 2555 } // 7 years
            }
          }
        }
      }
    ]
    blobContainers: [
      { name: 'application-data', publicAccess: 'None' }
      { name: 'application-logs', publicAccess: 'None' }
      { name: 'database-backups', publicAccess: 'None' }
      { name: 'vulnerability-assessment', publicAccess: 'None' }
    ]
    fileShares: [
      {
        name: 'shared-files'
        shareQuota: 1024
        enabledProtocols: 'SMB'
        accessTier: 'TransactionOptimized'
      }
    ]
  }
}
```

#### Storage Account Configuration Options

- **Performance Tiers**: Standard (LRS, GRS, ZRS, GZRS) and Premium (LRS, ZRS) options
- **Security Features**:
  - Network isolation with private endpoints and firewall rules
  - Infrastructure encryption for enhanced security
  - Blob versioning and soft delete for data protection
  - Customer-managed encryption keys (CMEK) support
- **Lifecycle Management**: Automated tiering and deletion policies for cost optimization
- **Access Controls**: Disable public blob access and shared key access for enhanced security
- **Monitoring**: Comprehensive diagnostic settings for all storage services (blob, file, queue, table)

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
- **Database Security**: 
  - Azure SQL Database with Transparent Data Encryption (TDE)
  - Advanced Data Security (Microsoft Defender for SQL)
  - Vulnerability Assessment with automated scanning and reporting
  - Azure AD authentication with group-based administration
  - Network isolation with private endpoints and firewall rules
  - Long-term backup retention with geo-redundant storage
- **Storage Security**:
  - Infrastructure encryption and customer-managed keys support
  - Blob versioning and soft delete for data protection
  - Network isolation with private endpoints and access controls
  - Lifecycle management for automated data tiering and retention
- **Key Vault Security**: 
  - Centralized secret and certificate management with RBAC authorization
  - Network access controls with subnet restrictions and IP allowlists
  - Soft delete protection with configurable retention periods
  - Purge protection for production environments to prevent accidental deletion
  - HSM-backed keys available with Premium SKU
- **Access Controls**: RBAC and network-based access restrictions across all data services
- **Audit Logging**: Comprehensive logging for security events and administrative operations

## Testing

### Module Testing Overview

The project includes comprehensive unit tests for infrastructure modules to validate configuration, functionality, and cloud compatibility. Testing is organized by module category with dedicated test scripts for compute and data layer components:

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

### Data Layer Module Testing

The project includes comprehensive testing for data layer modules to validate security features, compliance, and integration:

#### Test Script Usage

```powershell
# Test all data layer modules
.\scripts\test-data-layer.ps1

# Test specific module
.\scripts\test-data-layer.ps1 -TestScope SqlServer
.\scripts\test-data-layer.ps1 -TestScope StorageAccount
.\scripts\test-data-layer.ps1 -TestScope PrivateEndpoints
.\scripts\test-data-layer.ps1 -TestScope Integration

# Test with verbose output for detailed information
.\scripts\test-data-layer.ps1 -VerboseOutput

# Test for specific environment
.\scripts\test-data-layer.ps1 -Environment staging -VerboseOutput
```

#### Test Coverage

The data layer test script validates the following aspects:

**SQL Server Module Tests:**
- Template syntax validation using `az bicep build`
- Azure AD authentication configuration with tenant integration
- Transparent Data Encryption (TDE) enablement validation
- Advanced Data Security (Microsoft Defender for SQL) configuration
- Network security settings including TLS 1.2 enforcement
- Backup and recovery configuration with retention policies
- Diagnostic settings and monitoring integration

**Storage Account Module Tests:**
- Template syntax validation
- Network access controls with subnet and IP restrictions
- Encryption configuration including infrastructure encryption
- Blob security features (versioning, soft delete, public access controls)
- Lifecycle management policies for automated data tiering
- Container and file share configuration validation

**Private Endpoints Module Tests:**
- Template syntax validation
- Supported service types validation (SQL, Storage, Key Vault, etc.)
- DNS zone configuration with cloud-compatible naming
- Private endpoint connectivity configuration
- Custom DNS configuration support
- Multi-cloud compatibility using Azure `environment()` function

**Integration Tests:**
- Main template integration validation
- Parameter file configuration checks
- Dependency management between data layer modules

#### Test Results

The data layer test script provides:
- ✓ Passed tests with detailed configuration validation
- ✗ Failed tests with specific error messages and troubleshooting guidance
- Test summary with comprehensive statistics
- Environment-specific validation results
- Security and compliance validation feedback

### Private Endpoints Module Testing

The project includes comprehensive testing for the private endpoints module to validate secure connectivity and cloud compatibility:

#### Test Script Usage

```powershell
# Test private endpoints module with syntax and configuration validation
.\scripts\test-private-endpoints.ps1

# Test with verbose output for detailed information
.\scripts\test-private-endpoints.ps1 -VerboseOutput

# Test for specific environment
.\scripts\test-private-endpoints.ps1 -Environment staging -VerboseOutput

# Validation-only mode (no resource group required)
.\scripts\test-private-endpoints.ps1 -ValidateOnly -VerboseOutput
```

#### Test Coverage

The private endpoints test script validates the following aspects:

**Module Syntax Validation:**
- Bicep template syntax validation using `az bicep build`
- Parameter schema validation and type checking
- Template compilation and ARM template generation

**Service Type Support:**
- SQL Server private endpoint configuration
- Storage Account private endpoints (Blob, File, Queue, Table)
- Key Vault private endpoint support
- Additional Azure services (Cosmos DB, Service Bus, Event Hub, etc.)
- Cloud-compatible DNS zone naming validation

**Configuration Validation:**
- Private endpoint parameter validation
- DNS integration and virtual network linking
- Network security and isolation testing
- Multi-cloud compatibility verification

**Cloud Compatibility Features:**
- Dynamic DNS suffix resolution using Azure `environment()` function
- Support for Azure Commercial, Government, and China clouds
- Automatic adaptation to different Azure environments
- Validation of cloud-specific DNS zone naming patterns

#### Test Results

The test script provides comprehensive output including:
- ✓ Passed tests with service type and configuration details
- ✗ Failed tests with detailed error messages and troubleshooting guidance
- Test summary with total, passed, and failed counts
- Cloud compatibility validation results
- Detailed configuration information when using `-VerboseOutput` parameter

## Deployed Infrastructure Components

The main template deploys the following infrastructure components:

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

### Data Layer Infrastructure

#### SQL Server and Database
- **Enterprise Database**: Azure SQL Database with configurable SKUs (Basic to Business Critical)
- **Security Features**:
  - Azure AD authentication with group-based administration
  - Transparent Data Encryption (TDE) for data at rest protection
  - Advanced Data Security (Microsoft Defender for SQL) with threat detection
  - Vulnerability Assessment with automated scanning and remediation guidance
  - Network isolation with private endpoints and subnet-based firewall rules
- **Backup & Recovery**:
  - Configurable short-term retention (7-35 days) for point-in-time restore
  - Long-term retention policies (weekly, monthly, yearly) for compliance
  - Geo-redundant backup storage for disaster recovery
  - Automated backup validation and testing
- **Monitoring & Compliance**: Comprehensive diagnostic settings with audit logging

#### Storage Account
- **Scalable Storage**: Azure Storage Account with configurable performance tiers
- **Security Controls**:
  - Network isolation with private endpoints and firewall rules
  - Infrastructure encryption with optional customer-managed keys
  - Blob versioning and soft delete for data protection
  - Disabled public blob access and shared key access for enhanced security
- **Lifecycle Management**: Automated data tiering and retention policies for cost optimization
- **Service Integration**: Pre-configured containers for application data, logs, backups, and security reports
- **File Services**: SMB file shares for shared application data and configuration

#### Private Endpoints (Conditional)
- **Secure Connectivity**: Private endpoints for SQL Database, Storage Account, and Key Vault
- **DNS Integration**: Automatic private DNS zone creation and virtual network linking with cloud-compatible naming
- **Multi-Cloud Support**: Dynamic DNS suffix resolution using Azure `environment()` function for Commercial, Government, and China clouds
- **Service Coverage**: Support for all Azure data services (SQL, Blob, File, Queue, Table, Key Vault)
- **Network Isolation**: Complete elimination of public internet access to data services

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
   
   # Verify SQL Database deployment
   az sql server list --resource-group contoso-webapp-dev-rg --output table
   az sql db list --resource-group contoso-webapp-dev-rg --server contoso-webapp-dev-sql --output table
   az sql server show --resource-group contoso-webapp-dev-rg --name contoso-webapp-dev-sql --query "{Name:name,FQDN:fullyQualifiedDomainName,AdminLogin:administratorLogin,PublicAccess:publicNetworkAccess}"
   
   # Verify Storage Account deployment
   az storage account list --resource-group contoso-webapp-dev-rg --output table
   az storage account show --resource-group contoso-webapp-dev-rg --name contosowebappdevsa --query "{Name:name,SKU:sku.name,Kind:kind,PublicAccess:publicNetworkAccess,HttpsOnly:supportsHttpsTrafficOnly}"
   
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
- **SQL Database Issues**:
  - Verify administrator credentials are secure and meet complexity requirements
  - Ensure Azure AD administrator object ID is valid and accessible
  - Check firewall rules allow access from required subnets
  - Validate that vulnerability assessment storage account is accessible
  - Ensure TLS 1.2 is supported by client applications
- **Storage Account Issues**:
  - Verify storage account name is globally unique and follows naming conventions
  - Check that network access rules allow required subnet access
  - Ensure lifecycle management rules don't conflict with application requirements
  - Validate that private endpoints are properly configured for network isolation
- **Private Endpoint Issues**:
  - Verify subnet has sufficient IP addresses for private endpoint allocation
  - Check that private DNS zones are properly linked to virtual networks
  - Ensure service endpoints are disabled on subnets using private endpoints
  - Validate that applications are configured to use private endpoint FQDNs
  - Confirm DNS zone names match the target Azure cloud environment (Commercial/Government/China)
- **Multi-Cloud Deployment Issues**:
  - Verify target Azure cloud environment is correctly detected by `environment()` function
  - Check that DNS suffixes are appropriate for the target cloud (e.g., .windows.net vs .usgovcloudapi.net)
  - Ensure service endpoints and private DNS zones use cloud-specific naming conventions
  - Validate that all Azure services are available in the target cloud region

## Contributing

This project follows Infrastructure as Code best practices. All changes should be:

1. Validated using the validation scripts
2. Security scanned with Checkov
3. Tested in development environment first
4. Reviewed before production deployment
5. Committed with clear, descriptive messages

## License

This project is licensed under the MIT License - see the LICENSE file for details.