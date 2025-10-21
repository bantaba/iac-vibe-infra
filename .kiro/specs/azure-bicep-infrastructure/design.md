# Azure Bicep Infrastructure Design Document

## Overview

This design document outlines the architecture and implementation approach for a modularized Azure Bicep infrastructure project that deploys a secure multi-tier application using Virtual Network Manager. The solution implements defense-in-depth security practices and follows Infrastructure as Code best practices.

## Architecture

### High-Level Architecture

The infrastructure follows a hub-and-spoke network topology managed by Azure Virtual Network Manager, with the following key components:

- **Network Layer**: Virtual Network Manager with centralized connectivity and security policies
- **Security Layer**: Application Gateway with WAF, Network Security Groups, DDoS Protection
- **Application Layer**: Multi-tier application deployment across availability zones
- **Data Layer**: Azure SQL Database with private endpoints and encryption
- **Management Layer**: Key Vault, Log Analytics, and monitoring solutions

### Network Architecture

The implemented network architecture provides a secure, multi-tier infrastructure:

```
Virtual Network Manager Scope
├── Network Groups (per environment)
│   ├── {env}-web-tier (Application Gateway, Web servers)
│   ├── {env}-business-tier (Application logic servers)  
│   └── {env}-data-tier (Database servers)
├── Security Admin Rules
│   ├── Deny RDP from Internet (Priority 100)
│   └── Deny SSH from Internet (Priority 110)
└── Connectivity Configurations
    └── Hub-and-Spoke topology setup

Environment-Specific Virtual Networks:
├── Development (10.0.0.0/16)
├── Staging (10.1.0.0/16)
└── Production (10.2.0.0/16)

Subnet Architecture (per environment):
├── Application Gateway Subnet (/24)
├── Management Subnet (/24)
├── Web Tier Subnet (/24)
├── Business Tier Subnet (/24)
├── Data Tier Subnet (/24)
└── Active Directory Subnet (/24)
```

**Current Implementation Status:**
- ✅ Virtual Network Manager with network groups and security policies
- ✅ Virtual Network with segmented subnets and service endpoints
- ✅ Network Security Groups with comprehensive tier-specific rules
- ✅ DDoS Protection Plan (conditional deployment for staging/production)
- ✅ Public IP Address module with Standard SKU and zone redundancy support
- ✅ Key Vault module with RBAC, network controls, and monitoring integration
- ✅ Application Gateway module with WAF, SSL termination, and backend pool management
- ✅ Load Balancer modules for internal traffic distribution
- ✅ SQL Server module with comprehensive security, backup, and monitoring features
- ✅ Storage Account module with lifecycle management, encryption, and private endpoint support
- ✅ Private Endpoints module for secure data service connectivity
- ⏳ Managed Identity and Security Center modules - Next phase
- ⏳ Monitoring modules (Log Analytics, Application Insights) - Next phase

## Components and Interfaces

### Module Structure

```
bicep-infrastructure/
├── main.bicep                 # Main orchestration template
├── parameters/
│   ├── dev.parameters.json    # Development environment parameters
│   ├── staging.parameters.json # Staging environment parameters
│   └── prod.parameters.json   # Production environment parameters
├── modules/
│   ├── networking/
│   │   ├── vnet-manager.bicep # Virtual Network Manager
│   │   ├── virtual-network.bicep # Virtual Network
│   │   ├── network-security-groups.bicep # NSG rules
│   │   ├── ddos-protection.bicep # DDoS protection plan
│   │   └── public-ip.bicep    # Public IP addresses ✅
│   ├── security/
│   │   ├── key-vault.bicep    # Key Vault with RBAC and network controls ✅
│   │   ├── managed-identity.bicep # Managed identities
│   │   └── security-center.bicep # Security Center configuration
│   ├── compute/
│   │   ├── application-gateway.bicep # Application Gateway with WAF
│   │   ├── load-balancer.bicep # Internal load balancers
│   │   ├── virtual-machines.bicep # VM scale sets
│   │   └── availability-sets.bicep # Availability configurations
│   ├── data/
│   │   ├── sql-server.bicep   # Azure SQL Database with security features ✅
│   │   ├── storage-account.bicep # Storage accounts with lifecycle management ✅
│   │   └── private-endpoints.bicep # Private endpoint configurations ✅
│   └── monitoring/
│       ├── log-analytics.bicep # Log Analytics workspace
│       ├── application-insights.bicep # Application monitoring
│       └── alerts.bicep       # Monitoring alerts
└── scripts/
    ├── deploy.ps1             # Deployment script
    └── validate.ps1           # Template validation script
```

### Core Interfaces

#### Virtual Network Manager Interface
- **Network Groups**: Logical grouping of virtual networks by environment and application tier
- **Connectivity Configurations**: Hub-and-spoke topology with optional mesh connectivity
- **Security Admin Rules**: Centralized security policies applied across network groups

#### Public IP Address Interface
- **SKU Configuration**: Support for Basic and Standard SKUs with conditional zone deployment
- **Allocation Methods**: Static (recommended) and Dynamic allocation support
- **Zone Redundancy**: Multi-zone deployment for Standard SKU enhancing availability
- **DNS Integration**: Configurable domain name labels for friendly DNS names
- **Comprehensive Outputs**: Resource ID, IP address, FQDN, and configuration details

#### Application Gateway Interface
- **Frontend Configuration**: Public IP with SSL certificate from Key Vault
- **Backend Pools**: Web tier virtual machines across availability zones
- **WAF Policies**: OWASP Core Rule Set with custom rules for application protection
- **Health Probes**: HTTP/HTTPS health checks for backend availability

#### Load Balancer Interface
- **Frontend IP**: Internal IP addresses for each application tier
- **Backend Pools**: Virtual machines in business and data tiers
- **Load Balancing Rules**: Distribution algorithms and session persistence
- **Health Probes**: TCP and HTTP health checks

#### SQL Server Interface
- **Database Configuration**: Configurable SKUs from Basic to Business Critical with vCore options
- **Security Features**:
  - Azure AD authentication with group-based administration and tenant integration
  - Transparent Data Encryption (TDE) for automatic data at rest protection
  - Advanced Data Security (Microsoft Defender for SQL) with threat detection
  - Vulnerability Assessment with automated scanning and remediation guidance
- **Network Security**: Private endpoint support with subnet-based firewall rules and TLS 1.2 enforcement
- **Backup & Recovery**: 
  - Short-term retention (7-35 days) for point-in-time restore
  - Long-term retention policies (weekly, monthly, yearly) for compliance requirements
  - Geo-redundant backup storage for disaster recovery scenarios
- **Monitoring Integration**: Comprehensive diagnostic settings for audit and performance logging

#### Storage Account Interface
- **Performance Tiers**: Standard (LRS, GRS, ZRS, GZRS) and Premium (LRS, ZRS) storage options
- **Security Controls**:
  - Network isolation with private endpoints and subnet-based firewall rules
  - Infrastructure encryption with optional customer-managed encryption keys (CMEK)
  - Blob versioning and soft delete for comprehensive data protection
  - Disabled public blob access and shared key access for enhanced security posture
- **Lifecycle Management**: Automated data tiering and retention policies for cost optimization
- **Service Integration**: Pre-configured containers and file shares for application requirements
- **Access Controls**: RBAC integration with managed identities for secure service-to-service access

#### Private Endpoints Interface
- **Service Coverage**: Support for SQL Database, Storage Account (Blob, File, Queue, Table), and Key Vault
- **DNS Integration**: Automatic private DNS zone creation and virtual network linking with cloud-compatible naming
- **Multi-Cloud Compatibility**: Dynamic DNS suffix resolution using Azure `environment()` function for deployment across Azure Commercial, Government, and China clouds
- **Network Isolation**: Complete elimination of public internet access to data services
- **Custom Configuration**: Support for existing DNS zones and custom DNS server configurations

#### Key Vault Interface
- **RBAC Authorization**: Built-in role assignments for secure access management
  - Key Vault Administrator: Full management permissions for administrators
  - Key Vault Secrets User: Read access to secrets for applications and services
  - Key Vault Certificate User: Certificate management for SSL/TLS operations
- **Network Security**: Configurable network access controls
  - Subnet-based access restrictions for VNet integration
  - IP allowlist support for specific client access
  - Azure Services bypass for platform integration
- **Data Protection**: Enterprise-grade security features
  - Soft delete with configurable retention period (7-90 days)
  - Purge protection to prevent accidental permanent deletion
  - Premium SKU support for HSM-backed cryptographic operations
- **Monitoring Integration**: Comprehensive observability
  - Diagnostic settings for Log Analytics workspace integration
  - Audit logging for all access and administrative operations
  - Telemetry tracking for deployment and usage analytics

## Data Models

### Resource Naming Convention

```bicep
// Naming convention parameters
param resourcePrefix string = 'contoso'
param environment string = 'prod'
param location string = 'eastus'
param workloadName string = 'webapp'

// Generated names
var namingConvention = {
  resourceGroup: '${resourcePrefix}-${workloadName}-${environment}-rg'
  virtualNetwork: '${resourcePrefix}-${workloadName}-${environment}-vnet'
  subnet: '${resourcePrefix}-${workloadName}-${environment}-${subnetType}-snet'
  networkSecurityGroup: '${resourcePrefix}-${workloadName}-${environment}-${subnetType}-nsg'
  applicationGateway: '${resourcePrefix}-${workloadName}-${environment}-agw'
  loadBalancer: '${resourcePrefix}-${workloadName}-${environment}-${tier}-lb'
  keyVault: '${resourcePrefix}${workloadName}${environment}kv'
  storageAccount: '${resourcePrefix}${workloadName}${environment}sa'
  sqlServer: '${resourcePrefix}-${workloadName}-${environment}-sql'
}
```

### Parameter Schema

```bicep
// Common parameters across all modules
@description('The prefix for all resource names')
param resourcePrefix string

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('The Azure region for deployment')
param location string = resourceGroup().location

@description('The workload or application name')
param workloadName string

@description('Tags to apply to all resources')
param tags object = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
  CostCenter: 'IT'
}
```

### Network Configuration Schema

```bicep
// Virtual Network configuration
type VirtualNetworkConfig = {
  addressSpace: string[]
  subnets: SubnetConfig[]
  dnsServers: string[]?
  enableDdosProtection: bool
}

type SubnetConfig = {
  name: string
  addressPrefix: string
  networkSecurityGroup: string?
  routeTable: string?
  serviceEndpoints: string[]?
  delegations: string[]?
}
```

### Public IP Configuration Schema

```bicep
// Public IP address configuration
type PublicIpConfig = {
  sku: 'Basic' | 'Standard'
  allocationMethod: 'Static' | 'Dynamic'
  ipVersion: 'IPv4' | 'IPv6'
  idleTimeoutInMinutes: int // 4-30 minutes
  domainNameLabel: string?
  zones: string[] // Availability zones for Standard SKU
}

// Public IP outputs
type PublicIpOutputs = {
  resourceId: string
  name: string
  ipAddress: string
  fqdn: string
  allocationMethod: string
  sku: string
  zones: string[]
}
```

### Security Configuration Schema

```bicep
// Key Vault configuration
type KeyVaultConfig = {
  sku: 'standard' | 'premium'
  enableSoftDelete: bool
  softDeleteRetentionInDays: int // 7-90 days
  enablePurgeProtection: bool
  enableRbacAuthorization: bool
  networkAcls: {
    bypass: 'AzureServices' | 'None'
    defaultAction: 'Allow' | 'Deny'
    ipRules: string[]?
    virtualNetworkRules: string[]?
  }
}

// Key Vault role assignments
type KeyVaultRoleAssignment = {
  principalId: string
  roleDefinitionId: string
  principalType: 'User' | 'ServicePrincipal' | 'Group'
}
```

### Data Layer Configuration Schema

```bicep
// SQL Server configuration
type SqlServerConfig = {
  sqlServerName: string
  sqlDatabaseName: string
  administratorLogin: string
  databaseSku: {
    name: string // Basic, Standard, Premium, GP_Gen5_2, BC_Gen5_4, etc.
    tier: string
    capacity: int
  }
  maxSizeBytes: int
  enableAzureAdAuthentication: bool
  azureAdAdministratorObjectId: string
  azureAdAdministratorLogin: string
  enableTransparentDataEncryption: bool
  enableAdvancedDataSecurity: bool
  enableVulnerabilityAssessment: bool
  enablePublicNetworkAccess: bool
  allowedSubnetIds: string[]
  allowedIpAddresses: string[]
  minimalTlsVersion: '1.0' | '1.1' | '1.2'
  backupRetentionDays: int // 7-35 days
  enableGeoRedundantBackup: bool
  enableLongTermRetention: bool
  longTermRetentionBackup: {
    weeklyRetention: string
    monthlyRetention: string
    yearlyRetention: string
    weekOfYear: int
  }
}

// Storage Account configuration
type StorageAccountConfig = {
  storageAccountName: string
  storageAccountSku: 'Standard_LRS' | 'Standard_GRS' | 'Standard_ZRS' | 'Standard_GZRS' | 'Premium_LRS' | 'Premium_ZRS'
  storageAccountKind: 'Storage' | 'StorageV2' | 'BlobStorage' | 'FileStorage' | 'BlockBlobStorage'
  accessTier: 'Hot' | 'Cool'
  enablePublicNetworkAccess: bool
  allowedSubnetIds: string[]
  allowedIpAddresses: string[]
  defaultNetworkAccessRule: 'Allow' | 'Deny'
  minimumTlsVersion: 'TLS1_0' | 'TLS1_1' | 'TLS1_2'
  enableHttpsTrafficOnly: bool
  enableBlobPublicAccess: bool
  enableInfrastructureEncryption: bool
  customerManagedKey: {
    enabled: bool
    keyVaultId: string
    keyName: string
    keyVersion: string
    userAssignedIdentityId: string
  }
  enableBlobVersioning: bool
  enableBlobSoftDelete: bool
  blobSoftDeleteRetentionDays: int
  enableLifecycleManagement: bool
  blobContainers: {
    name: string
    publicAccess: 'None' | 'Blob' | 'Container'
    metadata: object
  }[]
  fileShares: {
    name: string
    shareQuota: int
    enabledProtocols: 'SMB' | 'NFS'
    accessTier: 'TransactionOptimized' | 'Hot' | 'Cool'
  }[]
}

// Private Endpoint configuration
type PrivateEndpointConfig = {
  name: string
  privateLinkServiceId: string
  groupId: 'sqlServer' | 'storageBlob' | 'storageFile' | 'storageQueue' | 'storageTable' | 'keyVault'
  subnetId: string
  enablePrivateDnsZones: bool
  customDnsServers: string[]
}
```

## Error Handling

### Deployment Validation

1. **Pre-deployment Validation**
   - Bicep template syntax validation using `az bicep build`
   - Parameter file validation against template schema
   - Resource naming convention compliance checks
   - Azure policy compliance validation

2. **Runtime Error Handling**
   - Conditional resource deployment based on environment
   - Graceful handling of resource conflicts
   - Rollback strategies for failed deployments
   - Dependency validation between modules

3. **Post-deployment Validation**
   - Resource health checks and connectivity tests
   - Security configuration validation
   - Performance baseline establishment
   - Compliance reporting

### Error Recovery Patterns

```bicep
// Conditional resource creation with error handling
resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: sku
    tier: 'Regional'
  }
  zones: (sku == 'Standard') ? zones : null // Conditional zone deployment
  properties: {
    publicIPAllocationMethod: allocationMethod
    publicIPAddressVersion: ipVersion
    idleTimeoutInMinutes: idleTimeoutInMinutes
    dnsSettings: domainNameLabel != null ? {
      domainNameLabel: domainNameLabel
    } : null // Conditional DNS configuration
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2023-05-01' = if (deployApplicationGateway) {
  name: namingConvention.applicationGateway
  location: location
  properties: {
    // Configuration properties
  }
}

// Key Vault with error handling for role assignments
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    // Key Vault configuration
  }
}

// Conditional role assignments with error handling
resource keyVaultRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultAdministrators: if (!empty(principalId)) {
  name: guid(keyVault.id, principalId, roleDefinitions.keyVaultAdministrator)
  scope: keyVault
  properties: {
    roleDefinitionId: roleDefinitions.keyVaultAdministrator
    principalId: principalId
    principalType: 'User'
  }
}]

// Output with conditional logic
output applicationGatewayId string = deployApplicationGateway ? applicationGateway.id : ''
output keyVaultUri string = keyVault.properties.vaultUri
```

## Testing Strategy

### Template Testing Approach

1. **Unit Testing**
   - Individual module validation using Bicep CLI
   - Parameter validation testing
   - Resource property validation
   - Naming convention compliance testing
   - **Compute Module Testing**: Comprehensive validation using `scripts/test-compute-modules.ps1`
   - **Data Layer Testing**: Comprehensive validation using `scripts/test-data-layer.ps1`

2. **Integration Testing**
   - End-to-end deployment testing in isolated environments
   - Cross-module dependency validation
   - Network connectivity testing
   - Security configuration validation
   - **Module Integration Testing**: Validates dependencies between data layer modules

3. **Security Testing**
   - Azure Security Center compliance checks
   - Network security group rule validation
   - Private endpoint connectivity testing
   - Key Vault access policy validation
   - **SQL Server Security Testing**: Azure AD authentication, TDE, Advanced Data Security validation
   - **Storage Account Security Testing**: Network access controls, encryption, blob security features

4. **Performance Testing**
   - Deployment time optimization
   - Resource provisioning validation
   - Load balancer configuration testing
   - Database performance baseline establishment

### Automated Testing Framework

The project includes dedicated test scripts for comprehensive module validation:

#### Data Layer Testing (`scripts/test-data-layer.ps1`)
- **SQL Server Module**: Template syntax, Azure AD authentication, TDE, Advanced Data Security, network security, backup policies, monitoring integration
- **Storage Account Module**: Template syntax, network access controls, encryption configuration, blob security features, lifecycle management, container/file share configuration
- **Private Endpoints Module**: Template syntax, service type support, DNS zone configuration, connectivity settings, custom DNS configuration, multi-cloud compatibility
- **Integration Testing**: Main template integration, parameter file validation, dependency management

#### Compute Module Testing (`scripts/test-compute-modules.ps1`)
- **Application Gateway Module**: Template syntax, WAF configuration, SSL certificate support, health probes, backend pool management
- **Load Balancer Module**: Template syntax, health probe functionality, load balancing rules, tier-specific configuration
- **Virtual Machine Module**: Template syntax, availability zone deployment, autoscaling configuration
- **Availability Set Module**: Template syntax, fault domain and update domain configuration

### Testing Environments

- **Development**: Minimal resource deployment for rapid iteration
- **Staging**: Full-scale deployment matching production configuration
- **Production**: Blue-green deployment strategy with rollback capabilities

### Validation Scripts

#### Template Validation Script
```powershell
# Template validation script
param(
    [Parameter(Mandatory=$true)]
    [string]$TemplateFile,
    
    [Parameter(Mandatory=$true)]
    [string]$ParameterFile,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName
)

# Validate Bicep template
az bicep build --file $TemplateFile

# Validate deployment
az deployment group validate `
    --resource-group $ResourceGroupName `
    --template-file $TemplateFile `
    --parameters @$ParameterFile
```

#### Data Layer Testing Script
```powershell
# Data layer module testing script
param(
    [Parameter(Mandatory=$false)]
    [string]$TestScope = "All",  # All, SqlServer, StorageAccount, PrivateEndpoints, Integration
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput
)

# Test specific modules or all data layer components
.\scripts\test-data-layer.ps1 -TestScope SqlServer -VerboseOutput
.\scripts\test-data-layer.ps1 -TestScope StorageAccount -Environment staging
.\scripts\test-data-layer.ps1 -TestScope PrivateEndpoints -VerboseOutput
.\scripts\test-data-layer.ps1 -TestScope Integration
```

#### Test Result Format
```
Starting Data Layer Unit Tests...
Test Scope: All
Environment: dev

Testing SQL Server Module...
✓ SQL Server template syntax
✓ SQL Server Azure AD authentication
✓ SQL Server Transparent Data Encryption
✓ SQL Server Advanced Data Security
✓ SQL Server network security configuration
✓ SQL Server backup and recovery configuration
✓ SQL Server diagnostic settings and monitoring

Testing Storage Account Module...
✓ Storage Account template syntax
✓ Storage Account network access controls
✓ Storage Account encryption configuration
✓ Storage Account blob security features
✓ Storage Account lifecycle management
✓ Storage Account container and file share configuration

Testing Private Endpoints Module...
✓ Private Endpoints template syntax
✓ Private Endpoints supported service types
✓ Private Endpoints DNS zone configuration
✓ Private Endpoints connectivity configuration
✓ Private Endpoints custom DNS configuration
✓ Private Endpoints multi-cloud compatibility

Testing Data Layer Integration...
✓ Data layer main template integration
✓ Data layer parameter file configurations
✓ Data layer dependency management

==================================================
Test Summary
==================================================
Total Tests: 21
Passed: 21
Failed: 0

All tests passed!
```

## Security Considerations

### Network Security

- **Network Segmentation**: Separate subnets for each application tier with NSG rules
- **Private Endpoints**: All data services accessible only through private endpoints
- **DDoS Protection**: Standard DDoS protection for all public-facing resources
- **Web Application Firewall**: OWASP Core Rule Set with custom application rules

### Identity and Access Management

- **Key Vault Security**: 
  - RBAC-based authorization with built-in Azure roles
  - Network access controls with subnet and IP restrictions
  - Soft delete protection with configurable retention (7-90 days)
  - Purge protection for production environments
  - HSM-backed keys support with Premium SKU
  - Comprehensive audit logging and diagnostic monitoring
- **Managed Identities**: System-assigned identities for all Azure services
- **Azure AD Integration**: Single sign-on and conditional access policies
- **Least Privilege Access**: Minimal required permissions for all service accounts

### Data Protection

- **Encryption at Rest**: All storage and database services encrypted
- **Encryption in Transit**: TLS 1.2+ for all communications
- **Backup and Recovery**: Automated backups with point-in-time recovery
- **Data Classification**: Sensitive data identification and protection

### Monitoring and Compliance

- **Centralized Logging**: All security events logged to Log Analytics
- **Security Alerts**: Automated alerting for security incidents
- **Compliance Reporting**: Regular compliance assessments and reporting
- **Audit Trail**: Complete audit trail for all administrative operations