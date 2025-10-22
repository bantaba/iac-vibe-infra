# Azure Bicep Infrastructure Architecture

## Recent Updates

### Virtual Network Manager Configuration Fix (Latest)

**Change**: Updated Virtual Network Manager `scopeId` parameter from `subscription().subscriptionId` to `subscription().id`

**Impact**: 
- Ensures proper Azure Resource Manager integration for subscription-level scope
- Aligns with Azure Bicep best practices for resource referencing
- Maintains compatibility with Azure's network management APIs

**Technical Details**:
- The `subscription().id` function returns the full resource ID format required by Virtual Network Manager
- The previous `subscription().subscriptionId` returned only the GUID, which is insufficient for ARM resource references
- This change ensures the Virtual Network Manager can properly manage network resources at the subscription scope

## Architecture Overview

This Azure Bicep infrastructure implements a secure, multi-tier application architecture with the following key components:

### Subscription-Level Deployment Architecture

```
Azure Subscription (targetScope: 'subscription')
├── Resource Groups (auto-created)
│   ├── Main Resource Group
│   ├── Monitoring Resource Group (optional)
│   └── Security Resource Group (optional)
├── Virtual Network Manager (subscription-scoped)
├── Security Center / Defender for Cloud (subscription-scoped)
└── Azure Policy Assignments (subscription-scoped)
```

### Network Architecture

```
Virtual Network Manager (Subscription Scope)
├── Network Groups
│   ├── {environment}-web-tier
│   ├── {environment}-business-tier
│   └── {environment}-data-tier
├── Connectivity Configurations
│   └── Hub-and-Spoke Topology
└── Security Admin Configurations
    └── High-Risk Port Blocking (RDP/SSH from Internet)

Virtual Network ({environment} Address Space)
├── Application Gateway Subnet (Public-facing)
├── Management Subnet (Administrative access)
├── Web Tier Subnet (Frontend servers)
├── Business Tier Subnet (Application logic)
├── Data Tier Subnet (Database servers)
└── Active Directory Subnet (Domain services)
```

### Security Architecture

```
Defense-in-Depth Security Layers:
1. Virtual Network Manager Security Admin Rules (Subscription-level)
2. Network Security Groups (Subnet-level)
3. Application Gateway WAF (Application-level)
4. Private Endpoints (Service-level)
5. Key Vault Access Policies (Secret-level)
6. Managed Identity RBAC (Identity-level)
7. Microsoft Defender for Cloud (Monitoring-level)
```

### Data Flow Architecture

```
Internet → Application Gateway (WAF) → Web Tier → Business Tier → Data Tier
                     ↓                      ↓           ↓           ↓
                Load Balancer         Load Balancer  Private    Private
                (Public IP)          (Internal)     Endpoints  Endpoints
                     ↓                      ↓           ↓           ↓
                VM Scale Sets         VM Scale Sets  SQL Server Storage
                (Web Servers)        (App Servers)  (Database) (Files/Blobs)
```

### Monitoring and Compliance Architecture

```
Azure Monitor Ecosystem:
├── Log Analytics Workspace (Centralized logging)
├── Application Insights (APM)
├── Diagnostic Settings (Resource-level logging)
├── Security Center (Security monitoring)
├── Azure Policy (Compliance enforcement)
└── Monitoring Alerts (Proactive notifications)
```

## Key Architectural Decisions

### 1. Subscription-Level Deployment
- **Decision**: Use `targetScope = 'subscription'` for main template
- **Rationale**: Enables centralized governance, cross-resource group orchestration, and subscription-scoped services
- **Benefits**: Single deployment manages entire infrastructure stack, simplified operations, enhanced security

### 2. Virtual Network Manager Integration
- **Decision**: Implement centralized network governance with Virtual Network Manager
- **Rationale**: Provides unified security policies and connectivity management across environments
- **Benefits**: Consistent security enforcement, simplified network topology management, compliance automation

### 3. Multi-Environment Configuration
- **Decision**: Environment-specific parameter files with conditional resource deployment
- **Rationale**: Cost optimization for development, production-ready configurations for higher environments
- **Benefits**: Flexible deployment options, cost control, environment-appropriate security

### 4. Modular Template Architecture
- **Decision**: Separate Bicep modules for each infrastructure layer
- **Rationale**: Reusability, maintainability, and independent testing of components
- **Benefits**: Easier maintenance, component reuse, simplified troubleshooting

### 5. Security-First Design
- **Decision**: Implement defense-in-depth security from the ground up
- **Rationale**: Meet enterprise security requirements and compliance standards
- **Benefits**: Comprehensive threat protection, regulatory compliance, reduced security risks

## Environment-Specific Configurations

### Development Environment
- **Focus**: Cost optimization and rapid development
- **Security**: Basic security controls, no private endpoints
- **Monitoring**: Minimal logging (30-day retention)
- **Availability**: Single-zone deployment, basic SKUs

### Staging Environment
- **Focus**: Production-like testing with enhanced security
- **Security**: DDoS protection, private endpoints enabled
- **Monitoring**: Extended logging (90-day retention)
- **Availability**: Multi-zone deployment, standard SKUs

### Production Environment
- **Focus**: Maximum security, availability, and performance
- **Security**: Full security stack, WAF_v2, Security Center enabled
- **Monitoring**: Comprehensive logging (365-day retention)
- **Availability**: Multi-zone deployment, premium SKUs

## Compliance and Governance

### Security Standards
- **Azure Security Benchmark**: Automated compliance assessment
- **CIS Controls**: Industry-standard security controls implementation
- **NIST Framework**: Cybersecurity framework alignment
- **ISO 27001**: Information security management standards

### Monitoring and Auditing
- **Continuous Monitoring**: Real-time security and performance monitoring
- **Audit Logging**: Comprehensive audit trails for all administrative operations
- **Compliance Reporting**: Automated compliance status reporting
- **Incident Response**: Integrated alerting and response workflows

This architecture provides a robust, secure, and scalable foundation for enterprise applications while maintaining operational simplicity and cost effectiveness across different environments.