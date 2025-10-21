# Contributing to Azure Bicep Infrastructure Project

Thank you for your interest in contributing to this Azure Bicep Infrastructure project! This document provides guidelines and information for contributors.

## Code of Conduct

This project adheres to a code of conduct that promotes a welcoming and inclusive environment. Please be respectful and professional in all interactions.

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Azure CLI with Bicep extension installed (see [tech stack](.kiro/steering/tech.md) for current versions)
- PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform)
- Git for version control
- Python 3.7+ and Checkov for security scanning (`pip install checkov`)
- Appropriate Azure permissions for testing (Contributor role on test resource groups)
- Access to the project's naming conventions and parameter schemas

### Development Setup

1. **Fork and clone the repository**:
   ```bash
   git clone https://github.com/[YOUR-USERNAME]/azure-bicep-infrastructure.git
   cd azure-bicep-infrastructure
   ```

2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Install dependencies**:
   ```powershell
   # Ensure Azure CLI and Bicep are up to date
   az upgrade
   az bicep upgrade
   
   # Install Checkov for security scanning
   pip install checkov
   ```

## Development Guidelines

### Project Structure Reference

Before making changes, familiarize yourself with:
- [Project Structure](README.md#project-structure) for complete directory layout
- [Naming Conventions](modules/shared/naming-conventions.bicep) for consistent resource naming
- [Parameter Schemas](modules/shared/parameter-schemas.bicep) for type definitions and validation
- [Common Variables](modules/shared/common-variables.bicep) for shared constants and configurations
- [Technology Stack](.kiro/steering/tech.md) for current tool versions and commands

### Infrastructure as Code Best Practices

- **Modularity**: Create reusable modules for different infrastructure components
- **Parameterization**: Use parameters for configurable values, avoid hardcoding
- **Naming Conventions**: Follow the established naming patterns in `modules/shared/naming-conventions.bicep`
- **Documentation**: Include clear descriptions for all parameters and resources
- **Security**: Follow security best practices and run Checkov scans

### Code Style

- Use consistent indentation (2 spaces for Bicep files)
- Include meaningful descriptions for all parameters and resources
- Use descriptive variable and resource names
- Follow the established module structure and organization

#### Bicep-Specific Guidelines
- Use `@description()` decorators for all parameters and outputs
- Leverage type imports from shared parameter schemas: `import { TagConfiguration } from '../shared/parameter-schemas.bicep'`
- Use `targetScope` appropriately (resourceGroup, subscription, managementGroup)
- Follow consistent Azure resource API versions across modules
- Use conditional deployment patterns: `resource myResource 'type@version' = if (condition)`
- Reference naming conventions module for consistent resource names

### Testing Requirements

Before submitting changes, ensure:

1. **Template Validation**:
   ```powershell
   # Basic validation
   .\scripts\validate.ps1 -TemplateFile main.bicep -ParameterFile parameters\dev.parameters.json -ResourceGroupName test-rg
   
   # Full validation including project structure
   .\scripts\validate.ps1 -TemplateFile main.bicep -ParameterFile parameters\dev.parameters.json -ResourceGroupName test-rg -ValidateStructure
   ```

2. **Security Scanning**:
   ```powershell
   # Use project's security scan script
   .\scripts\security-scan.ps1 -Directory . -OutputFormat cli
   
   # Generate detailed report
   .\scripts\security-scan.ps1 -Directory . -OutputFormat json -OutputFile security-report.json
   
   # Soft fail mode (continue despite issues)
   .\scripts\security-scan.ps1 -Directory . -SoftFail
   ```

3. **Module Testing**:
   ```powershell
   # Test all compute modules
   .\scripts\test-compute-modules.ps1
   
   # Test specific compute module with verbose output
   .\scripts\test-compute-modules.ps1 -TestScope ApplicationGateway -VerboseOutput
   
   # Test all data layer modules
   .\scripts\test-data-layer.ps1
   
   # Test specific data layer module with verbose output
   .\scripts\test-data-layer.ps1 -TestScope SqlServer -VerboseOutput
   .\scripts\test-data-layer.ps1 -TestScope StorageAccount -VerboseOutput
   .\scripts\test-data-layer.ps1 -TestScope PrivateEndpoints -VerboseOutput
   
   # Test for specific environment
   .\scripts\test-compute-modules.ps1 -Environment staging -VerboseOutput
   .\scripts\test-data-layer.ps1 -Environment staging -VerboseOutput
   ```

4. **Deployment Testing**:
   ```powershell
   # Development deployment with what-if preview
   .\scripts\deploy.ps1 -Environment dev -ResourceGroupName contoso-webapp-dev-test-rg -WhatIf
   
   # Full deployment
   .\scripts\deploy.ps1 -Environment dev -ResourceGroupName contoso-webapp-dev-test-rg
   
   # Skip validation and security scan (for rapid iteration)
   .\scripts\deploy.ps1 -Environment dev -ResourceGroupName contoso-webapp-dev-test-rg -SkipValidation -SkipSecurityScan
   ```

5. **Testing Best Practices**:
   - Test in a development environment first
   - Use unique resource group names: `{prefix}-{workload}-dev-{username}-rg`
   - Verify all resources deploy successfully
   - Validate security configurations and network connectivity
   - Clean up test resources to manage costs
   - Use what-if analysis before production deployments

## Contribution Process

### 1. Issue Creation

- Check existing issues before creating new ones
- Use issue templates when available
- Provide clear descriptions and reproduction steps
- Label issues appropriately (bug, enhancement, documentation, etc.)

### 2. Pull Request Process

1. **Create a feature branch** from `main`
2. **Make your changes** following the guidelines above
3. **Test thoroughly** using the validation scripts
4. **Update documentation** if needed
5. **Submit a pull request** with:
   - Clear title and description
   - Reference to related issues
   - Screenshots or examples if applicable
   - Checklist of completed testing

### 3. Pull Request Review

- All PRs require review before merging
- Address reviewer feedback promptly
- Ensure CI/CD checks pass
- Squash commits if requested

## Types of Contributions

### Bug Fixes
- Fix template syntax errors
- Resolve deployment issues
- Correct security misconfigurations

### New Features
- Add new Azure service modules
- Enhance existing functionality
- Improve automation scripts

### Documentation
- Update README files
- Add code comments
- Create usage examples
- Improve inline documentation

### Security Improvements
- Address Checkov findings
- Implement security best practices
- Add new security controls

## Module Development Guidelines

### Creating New Modules

1. **Follow the established structure**:
   ```
   modules/
   └── category/
       └── service-name.bicep
   ```

2. **Include standard elements**:
   - Parameter validation with `@allowed` and `@description`
   - Consistent naming using the naming conventions module
   - Proper resource dependencies
   - Meaningful outputs
   - Security configurations

3. **Example module template**:
   ```bicep
   @description('Description of the module purpose')
   
   // Parameters
   @description('The environment name')
   @allowed(['dev', 'staging', 'prod'])
   param environment string
   
   // Variables
   var resourceName = 'example-${environment}'
   
   // Resources
   resource exampleResource 'Microsoft.Example/resources@2023-01-01' = {
     name: resourceName
     location: resourceGroup().location
     properties: {
       // Configuration
     }
   }
   
   // Outputs
   @description('The resource ID')
   output resourceId string = exampleResource.id
   ```

### Testing New Modules

- Create parameter files for testing
- Validate with Azure CLI
- Run security scans
- Test in isolated environment
- Document usage examples

### Testing Data Layer Modules

The project includes comprehensive unit tests for data layer modules. Use the dedicated test script to validate SQL Server, Storage Account, and Private Endpoints configurations:

#### Data Layer Test Script Usage

```powershell
# Test all data layer modules
.\scripts\test-data-layer.ps1

# Test specific modules
.\scripts\test-data-layer.ps1 -TestScope SqlServer
.\scripts\test-data-layer.ps1 -TestScope StorageAccount
.\scripts\test-data-layer.ps1 -TestScope PrivateEndpoints
.\scripts\test-data-layer.ps1 -TestScope Integration

# Test with verbose output for detailed validation information
.\scripts\test-data-layer.ps1 -VerboseOutput

# Test for specific environment
.\scripts\test-data-layer.ps1 -Environment staging -VerboseOutput
```

#### Data Layer Test Coverage

The test script validates:

**SQL Server Module:**
- Template syntax and compilation
- Azure AD authentication configuration
- Transparent Data Encryption (TDE) settings
- Advanced Data Security (Microsoft Defender for SQL)
- Network security and TLS configuration
- Backup and recovery policies
- Diagnostic settings and monitoring

**Storage Account Module:**
- Template syntax validation
- Network access controls and firewall rules
- Encryption configuration (infrastructure encryption, CMEK support)
- Blob security features (versioning, soft delete, public access controls)
- Lifecycle management policies
- Container and file share configurations

**Private Endpoints Module:**
- Template syntax validation
- Supported service types (SQL, Storage, Key Vault, etc.)
- DNS zone configuration with cloud compatibility
- Private endpoint connectivity settings
- Custom DNS configuration support
- Multi-cloud compatibility validation

**Integration Testing:**
- Main template module integration
- Parameter file validation
- Dependency management verification

### Testing Key Vault Module

When testing the Key Vault module:

1. **Parameter Validation**:
   ```powershell
   # Test with minimal configuration
   az deployment group validate --resource-group test-rg --template-file modules/security/key-vault.bicep --parameters keyVaultName=testkv123 location="East US" tags='{Environment:"test"}'
   ```

2. **RBAC Testing**:
   - Use your own object ID for administrator role testing
   - Create test managed identities for service principal role testing
   - Verify role assignments are created correctly

3. **Network Security Testing**:
   - Test with default network restrictions (deny all)
   - Test with subnet allowlist configuration
   - Verify IP allowlist functionality

4. **Monitoring Integration**:
   - Deploy with Log Analytics workspace integration
   - Verify diagnostic settings are configured
   - Test audit log generation

### Testing SQL Server Module

When testing the SQL Server module:

1. **Parameter Validation**:
   ```powershell
   # Test with minimal configuration
   az deployment group validate --resource-group test-rg --template-file modules/data/sql-server.bicep --parameters sqlServerName=testsql123 sqlDatabaseName=testdb administratorLogin=sqladmin administratorLoginPassword='SecurePass123!' tags='{Environment:"test"}'
   ```

2. **Security Configuration Testing**:
   - Test Azure AD authentication with valid object IDs
   - Verify Transparent Data Encryption enablement
   - Test Advanced Data Security configuration
   - Validate vulnerability assessment setup with storage account

3. **Network Security Testing**:
   - Test with private network access (public access disabled)
   - Verify subnet-based firewall rules
   - Test IP address allowlist functionality
   - Validate TLS 1.2 enforcement

4. **Backup and Recovery Testing**:
   - Verify short-term retention policy configuration
   - Test long-term retention policy setup
   - Validate geo-redundant backup configuration
   - Test point-in-time restore capabilities

### Testing Storage Account Module

When testing the Storage Account module:

1. **Parameter Validation**:
   ```powershell
   # Test with minimal configuration
   az deployment group validate --resource-group test-rg --template-file modules/data/storage-account.bicep --parameters storageAccountName=teststorage123 tags='{Environment:"test"}'
   ```

2. **Security Configuration Testing**:
   - Test network access restrictions with subnet allowlists
   - Verify infrastructure encryption enablement
   - Test blob versioning and soft delete functionality
   - Validate customer-managed key configuration (if enabled)

3. **Lifecycle Management Testing**:
   - Verify lifecycle policy creation and rules
   - Test automated data tiering functionality
   - Validate retention and deletion policies

4. **Container and File Share Testing**:
   - Verify blob container creation with proper access levels
   - Test file share creation with appropriate quotas and protocols
   - Validate metadata and configuration settings

### Testing Private Endpoints Module

When testing the Private Endpoints module:

1. **Parameter Validation**:
   ```powershell
   # Test with minimal configuration
   az deployment group validate --resource-group test-rg --template-file modules/data/private-endpoints.bicep --parameters privateEndpointNamePrefix=test-pe subnetId='/subscriptions/.../subnets/test' virtualNetworkId='/subscriptions/.../vnets/test' privateEndpointConfigs='[]' tags='{Environment:"test"}'
   
   # Use the dedicated test script for comprehensive validation
   .\scripts\test-private-endpoints.ps1 -ValidateOnly -VerboseOutput
   ```

2. **DNS Integration Testing**:
   - Verify private DNS zone creation for each service type with cloud-compatible naming
   - Test virtual network linking functionality
   - Validate DNS resolution for private endpoints
   - Confirm cloud-specific DNS suffix usage (Commercial/Government/China)

3. **Multi-Cloud Compatibility Testing**:
   - Test DNS zone naming with `environment()` function across different Azure clouds
   - Verify automatic adaptation to cloud-specific service endpoints
   - Validate private DNS zone creation for target cloud environment
   - Test template portability across Azure Commercial, Government, and China clouds

4. **Connectivity Testing**:
   - Test private endpoint creation for SQL Database
   - Verify storage account private endpoint connectivity
   - Test Key Vault private endpoint functionality
   - Validate network isolation and security

## Security Considerations

### Sensitive Information
- Never commit secrets, keys, or passwords to the repository
- Use Key Vault references in parameter files: `"@Microsoft.KeyVault(SecretUri=https://...)"` 
- Review .gitignore to ensure proper exclusions of credential files
- Use Azure CLI authentication (`az login`) instead of service principal credentials in files
- Never commit `.azure` directories or Azure credential files
- Reference secrets in Bicep templates using Key Vault resource references

### Key Vault Module Security
- **RBAC Configuration**: Use proper object IDs for role assignments (users, service principals, managed identities)
- **Network Security**: Configure subnet restrictions and IP allowlists appropriately for your environment
- **Soft Delete**: Always enable soft delete with appropriate retention period (minimum 7 days, recommended 90 days for production)
- **Purge Protection**: Enable for production environments to prevent accidental permanent deletion
- **Monitoring**: Enable diagnostic settings to track access patterns and security events

### Security Scanning
- Run Checkov before submitting PRs
- Address high and medium severity findings
- Document any accepted risks with justification

### Access Controls
- Follow principle of least privilege
- Use managed identities where possible
- Implement proper RBAC configurations

## Documentation Standards

### Code Documentation
- Use `@description` for all parameters and outputs
- Include usage examples in module headers
- Document complex logic with comments

### README Updates
- Update feature lists for new capabilities
- Include new prerequisites or setup steps
- Add usage examples for new modules

### Changelog Maintenance
- Follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format
- Document all user-facing changes
- Include security fixes and improvements

## Getting Help

- Create an issue for questions or problems
- Check existing documentation and examples
- Review Azure Bicep documentation for syntax questions
- Use descriptive titles and provide context

## Recognition

Contributors will be recognized in:
- GitHub contributor statistics
- Release notes for significant contributions
- Project documentation acknowledgments

Thank you for contributing to making this Azure Bicep Infrastructure project better!