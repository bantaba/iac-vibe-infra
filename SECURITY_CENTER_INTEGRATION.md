# Security Center Integration Guide

## Overview

The Security Center module provides subscription-level security monitoring and threat protection through Microsoft Defender for Cloud. This document outlines the integration, configuration, and recent improvements to the module.

## Recent Updates

### Telemetry Deployment Enhancement (Latest)

The Security Center module has been improved with enhanced telemetry deployment resource configuration:

**Change**: Enhanced telemetry deployment resource naming and location specification for better deployment reliability.

**Before**:
```bicep
resource telemetryDeployment 'Microsoft.Resources/deployments@2022-09-01' = if (enableTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name)}'
  properties: {
    mode: 'Incremental'
    // ...
  }
}
```

**After**:
```bicep
resource telemetryDeployment 'Microsoft.Resources/deployments@2022-09-01' = if (enableTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name, location)}'
  location: location
  properties: {
    mode: 'Incremental'
    // ...
  }
}
```

**Benefits**:
- Improved resource name uniqueness by including location in the unique string generation
- Explicit location specification ensures proper regional deployment of telemetry resources
- Enhanced deployment reliability across different Azure regions and environments
- Better tracking and management of telemetry resources in multi-region deployments

### Conditional Output Generation

The Security Center module has been enhanced with conditional output generation to improve deployment reliability across different environments:

**Change**: Added conditional logic to module outputs to prevent resource reference errors when Defender plans are disabled.

**Before**:
```bicep
output defenderPlansConfig array = [for (plan, i) in defenderPlans: {
  name: plan.name
  tier: defenderForCloudPlans[i].properties.pricingTier
  subPlan: defenderForCloudPlans[i].properties.subPlan
  resourceId: defenderForCloudPlans[i].id
}]
```

**After**:
```bicep
output defenderPlansConfig array = [for (plan, i) in defenderPlans: if (enableDefenderPlans) {
  name: plan.name
  tier: defenderForCloudPlans[i].properties.pricingTier
  subPlan: defenderForCloudPlans[i].properties.subPlan
  resourceId: defenderForCloudPlans[i].id
}]
```

**Benefits**:
- Prevents deployment errors in development environments where Defender plans are disabled
- Maintains template compatibility across all environments
- Ensures proper resource referencing without breaking conditional deployments
- Improves cost optimization by avoiding unnecessary resource creation in development

## Environment-Specific Configuration

### Development Environment
- **Defender Plans**: Disabled (`enableDefenderPlans: false`)
- **Cost Optimization**: No Defender plan charges incurred
- **Security Monitoring**: Basic Azure Security Center features only
- **Outputs**: Empty arrays and objects returned to maintain template compatibility

### Staging Environment
- **Defender Plans**: Enabled (`enableDefenderPlans: true`)
- **Full Protection**: All Defender plans activated for production-like testing
- **Security Monitoring**: Comprehensive threat detection and vulnerability assessment
- **Outputs**: Complete configuration objects with resource IDs and settings

### Production Environment
- **Defender Plans**: Enabled (`enableDefenderPlans: true`)
- **Maximum Security**: All Defender plans with enhanced monitoring
- **Compliance**: Full security posture management and compliance reporting
- **Outputs**: Complete configuration objects with resource IDs and settings

## Module Integration

### Main Template Integration

The Security Center module is integrated into the main template with conditional deployment:

```bicep
module securityCenter 'modules/security/security-center.bicep' = {
  name: 'security-center-deployment'
  scope: subscription()
  params: {
    subscriptionId: subscription().subscriptionId
    tags: tags
    enableDefenderPlans: environment != 'dev' // Conditional based on environment
    defenderPlans: [
      // Comprehensive list of Defender plans
    ]
    securityContacts: [
      // Security contact configuration
    ]
    autoProvisioningSettings: {
      // Auto-provisioning configuration
    }
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.workspaceId
    enableTelemetry: true
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}
```

### Output Consumption

The main template consumes Security Center outputs with conditional logic:

```bicep
output security object = {
  securityCenter: environment != 'dev' ? {
    defenderPlansConfig: securityCenter.outputs.defenderPlansConfig
    securityContactsConfig: securityCenter.outputs.securityContactsConfig
    autoProvisioningConfig: securityCenter.outputs.autoProvisioningConfig
    workspaceSettingsConfig: securityCenter.outputs.workspaceSettingsConfig
    securityPolicyAssignment: securityCenter.outputs.securityPolicyAssignment
    customSecurityAssessment: securityCenter.outputs.customSecurityAssessment
    securityCenterConfig: securityCenter.outputs.securityCenterConfig
  } : {
    defenderPlansConfig: []
    securityContactsConfig: []
    autoProvisioningConfig: {}
    workspaceSettingsConfig: {}
    securityPolicyAssignment: {}
    customSecurityAssessment: {}
    securityCenterConfig: {}
  }
}
```

## Defender Plans Configuration

### Supported Defender Plans

The module supports the following Microsoft Defender plans:

1. **Virtual Machines** (`VirtualMachines`)
   - Tier: Standard
   - Sub-plan: P2 (Advanced threat detection)
   - Features: Behavioral analytics, file integrity monitoring, adaptive application controls

2. **App Services** (`AppServices`)
   - Tier: Standard
   - Features: Web application security monitoring, runtime protection

3. **SQL Servers** (`SqlServers`)
   - Tier: Standard
   - Features: SQL injection detection, vulnerability assessment, threat intelligence

4. **SQL Server Virtual Machines** (`SqlServerVirtualMachines`)
   - Tier: Standard
   - Features: SQL-specific threat detection for VMs

5. **Storage Accounts** (`StorageAccounts`)
   - Tier: Standard
   - Sub-plan: DefenderForStorageV2
   - Features: Malware scanning, activity monitoring, threat intelligence

6. **Key Vaults** (`KeyVaults`)
   - Tier: Standard
   - Features: Secret and certificate access monitoring, anomaly detection

7. **Azure Resource Manager** (`Arm`)
   - Tier: Standard
   - Features: Control plane protection, suspicious activity detection

8. **Open Source Relational Databases** (`OpenSourceRelationalDatabases`)
   - Tier: Standard
   - Features: PostgreSQL and MySQL threat protection

9. **Containers** (`Containers`)
   - Tier: Standard
   - Features: Container image scanning, runtime protection

10. **Cloud Security Posture Management** (`CloudPosture`)
    - Tier: Standard
    - Features: Security posture assessment, compliance monitoring

## Security Contacts Configuration

### Contact Settings

```bicep
securityContacts: [
  {
    email: 'security@contoso.com'
    phone: '+1-555-0123'
    alertNotifications: 'On'
    notificationsByRole: 'On'
  }
]
```

### Notification Configuration
- **Alert Notifications**: Receive security alerts via email
- **Notifications by Role**: Notify subscription owners and contributors
- **Minimal Severity**: Medium and above (configurable)
- **Roles**: Owner, Contributor (configurable)

## Auto-Provisioning Settings

### Supported Auto-Provisioning Options

```bicep
autoProvisioningSettings: {
  logAnalytics: 'On'                    // Log Analytics agent
  microsoftDefenderForEndpoint: 'On'   // Defender for Endpoint integration
  vulnerabilityAssessment: 'On'        // Vulnerability assessment extension
  guestConfiguration: 'On'             // Guest configuration extension
}
```

## Testing and Validation

### Security Center Integration Testing

Use the dedicated test script to validate Security Center configuration:

```powershell
# Test Security Center module integration
.\scripts\test-security-center-integration.ps1

# Test with verbose output
.\scripts\test-security-center-integration.ps1 -VerboseOutput

# Test for specific environment
.\scripts\test-security-center-integration.ps1 -Environment staging -VerboseOutput
```

### Test Coverage

The test script validates:
- Template syntax and compilation
- Main template integration with subscription scope
- Parameter file compatibility
- Defender plans configuration
- Security contacts and notification settings
- Auto-provisioning settings
- Log Analytics workspace integration
- Output generation and conditional logic

## Troubleshooting

### Common Issues

1. **Permission Errors**
   - Ensure Security Admin or Contributor role at subscription level
   - Verify permissions to create policy assignments and security settings

2. **Defender Plan Availability**
   - Check that all Defender plans are available in your subscription type
   - Verify regional availability for specific Defender plans

3. **Output Reference Errors**
   - Ensure conditional logic is properly implemented in consuming templates
   - Verify that `enableDefenderPlans` parameter is correctly set
   - Check that output references use conditional expressions when needed

4. **Log Analytics Integration**
   - Ensure Log Analytics workspace exists before Security Center deployment
   - Verify workspace permissions for Security Center integration
   - Check that workspace is in the same subscription or has cross-subscription access

### Best Practices

1. **Environment Configuration**
   - Use conditional deployment based on environment type
   - Disable Defender plans in development for cost optimization
   - Enable full protection in staging and production environments

2. **Security Contacts**
   - Use distribution lists for security contacts
   - Ensure contact information is current and monitored
   - Configure appropriate notification thresholds

3. **Integration**
   - Deploy Log Analytics workspace before Security Center
   - Use conditional outputs to maintain template compatibility
   - Implement proper dependency management between modules

4. **Monitoring**
   - Regularly review security recommendations and alerts
   - Monitor compliance status and security posture
   - Implement automated response to critical security alerts

## Related Documentation

- [Security Center Module](modules/security/security-center.bicep)
- [Main Template Integration](main.bicep)
- [Security Testing Guide](scripts/test-security-center-integration.ps1)
- [Environment Configuration](parameters/)
- [Main README](README.md)
- [Troubleshooting Guide](README.md#troubleshooting-common-issues)