# Project Structure

## Directory Organization

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
│   ├── security-scan.ps1      # Checkov security scanning script
│   ├── test-compute-modules.ps1 # Compute module unit tests
│   ├── test-data-layer.ps1    # Data layer module unit tests
│   └── test-private-endpoints.ps1 # Private endpoints module tests
├── .checkov.yaml              # Checkov configuration file
└── .checkovignore             # Checkov ignore patterns
```

## Module Organization

### Networking Modules (`modules/networking/`)
- `vnet-manager.bicep` - Virtual Network Manager configuration
- `virtual-network.bicep` - Virtual networks and subnets
- `network-security-groups.bicep` - NSG rules and associations
- `ddos-protection.bicep` - DDoS protection plans

### Security Modules (`modules/security/`)
- `key-vault.bicep` - Key Vault and secret management
- `managed-identity.bicep` - System and user-assigned identities
- `security-center.bicep` - Security Center configuration

### Compute Modules (`modules/compute/`)
- `application-gateway.bicep` - Application Gateway with WAF
- `load-balancer.bicep` - Internal load balancers
- `virtual-machines.bicep` - VM scale sets and configurations
- `availability-sets.bicep` - Availability and fault domains

### Data Modules (`modules/data/`)
- `sql-server.bicep` - Azure SQL Database configuration
- `storage-account.bicep` - Storage accounts with security
- `private-endpoints.bicep` - Private endpoint configurations

### Monitoring Modules (`modules/monitoring/`)
- `log-analytics.bicep` - Log Analytics workspace
- `application-insights.bicep` - Application performance monitoring
- `alerts.bicep` - Monitoring alerts and notifications

## Naming Conventions

### Resource Naming Pattern
`{resourcePrefix}-{workloadName}-{environment}-{resourceType}`

Examples:
- Resource Group: `contoso-webapp-prod-rg`
- Virtual Network: `contoso-webapp-prod-vnet`
- Application Gateway: `contoso-webapp-prod-agw`
- Key Vault: `contosowebappprodkv` (no hyphens due to naming restrictions)

### File Naming
- Bicep modules: `kebab-case.bicep`
- Parameter files: `{environment}.parameters.json`
- PowerShell scripts: `PascalCase.ps1`

## Architecture Patterns

### Module Dependencies
1. **Networking** - Foundation layer (VNet Manager, VNets, NSGs)
2. **Security** - Identity and secret management (Key Vault, Managed Identity)
3. **Compute** - Application layer (Application Gateway, Load Balancers, VMs)
4. **Data** - Storage and database layer (SQL Database, Storage Accounts)
5. **Monitoring** - Observability layer (Log Analytics, Application Insights)

### Parameter Management
- Environment-specific parameters in separate JSON files
- Common parameters defined in main template
- Sensitive values referenced from Key Vault
- Consistent tagging strategy across all resources

### Security Architecture
- **Defense in Depth**: Multiple security layers (WAF, NSGs, private endpoints)
- **Least Privilege**: Minimal required permissions for all identities
- **Zero Trust**: No implicit trust, verify everything
- **Centralized Secrets**: All secrets managed through Key Vault
- **Security Scanning**: Checkov integration for continuous security validation
- **Compliance Automation**: Automated security policy enforcement and reporting