# Changelog

All notable changes to this Azure Bicep Infrastructure project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Security Center Integration**: Microsoft Defender for Cloud deployment with subscription-level security monitoring
- Comprehensive Defender plans for VMs, App Services, SQL, Storage, Key Vault, ARM, Containers, and Cloud Posture
- Security contacts configuration with email and phone notifications for security alerts
- Auto-provisioning settings for Log Analytics agents, Defender for Endpoint, vulnerability assessment, and guest configuration
- Environment-specific Security Center deployment (disabled for dev, enabled for staging/prod)
- Integration with Log Analytics workspace for centralized security telemetry
- Security Center integration testing with `test-security-center-integration.ps1`
- Comprehensive compute module unit testing framework with `test-compute-modules.ps1`
- Test coverage for Application Gateway, Load Balancer, Virtual Machine, and Availability Set modules
- Support for verbose output and environment-specific testing in test scripts
- Integrated networking modules into main orchestration template
- Virtual Network deployment with multi-tier subnet architecture
- Network Security Groups with comprehensive security rules for each tier
- Virtual Network Manager with centralized network governance and security policies
- DDoS Protection Plan with conditional deployment based on environment
- Service endpoints configuration for secure Azure service connectivity
- Environment-specific network address spaces (10.0.x.x for dev, 10.1.x.x for staging, 10.2.x.x for prod)

### Enhanced
- Updated test script parameter from `-Verbose` to `-VerboseOutput` to avoid PowerShell conflicts
- Main template now orchestrates complete networking infrastructure deployment
- Improved dependency management between networking modules
- Enhanced security with tier-specific NSG rules following principle of least privilege
- Added comprehensive outputs for networking resources (IDs, names, configurations)

### Security
- **Enhanced Security Posture**: Subscription-level security monitoring with Microsoft Defender for Cloud
- Advanced threat detection and vulnerability assessment across all Azure services
- Real-time security alerts and incident response capabilities
- Security posture management with continuous compliance assessment
- Implemented defense-in-depth networking security architecture
- Added Virtual Network Manager security admin rules blocking high-risk ports from internet
- Configured private endpoint network policies for enhanced data service security
- Established proper network segmentation with controlled inter-tier communication

## [1.0.0] - 2024-10-20

### Added
- Initial Azure Bicep Infrastructure as Code project setup
- Modular architecture with reusable Bicep templates
- Multi-environment support (dev, staging, production)
- Security-first design with defense-in-depth principles
- Azure Virtual Network Manager implementation
- Application Gateway with Web Application Firewall (WAF)
- Network Security Groups with comprehensive rule sets
- Key Vault integration for secret management
- Managed Identity for secure service-to-service authentication
- SQL Database with private endpoints
- Storage Account with security configurations
- Log Analytics and Application Insights monitoring
- Automated deployment and validation PowerShell scripts
- Checkov security scanning integration
- Comprehensive naming conventions module with validation
- Parameter schemas for type safety
- Common variables and configuration constants
- Git repository with proper .gitignore and documentation

### Security
- DDoS protection for public resources
- Private endpoints for data services
- Network segmentation with NSGs
- Centralized secret management
- Security scanning with Checkov
- Compliance validation and reporting

### Infrastructure Components
- **Networking**: Virtual Network Manager, VNets, Subnets, NSGs, DDoS Protection
- **Security**: Key Vault, Managed Identity, Security Center
- **Compute**: Application Gateway, Load Balancers, Virtual Machines, Availability Sets
- **Data**: SQL Server/Database, Storage Accounts, Private Endpoints
- **Monitoring**: Log Analytics, Application Insights, Alerts

### Documentation
- Comprehensive README with setup and deployment instructions
- Inline code documentation and examples
- Project structure and architecture overview
- Security features and best practices
- Git workflow and contribution guidelines