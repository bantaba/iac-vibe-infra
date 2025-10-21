// Azure Policy module for security and governance compliance
// This module implements policy definitions, assignments, and compliance reporting

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

@description('Enable built-in Azure Security Benchmark policies')
param enableSecurityBenchmark bool = true

@description('Enable custom organizational policies')
param enableCustomPolicies bool = true

@description('Policy assignment scope (subscription or resourceGroup)')
@allowed(['subscription', 'resourceGroup'])
param policyScope string = 'resourceGroup'

@description('Email addresses for compliance notifications')
param complianceNotificationEmails array = []

// Variables for naming convention
var namingConvention = {
  policyDefinition: '${resourcePrefix}-${workloadName}-${environment}-policy'
  policyAssignment: '${resourcePrefix}-${workloadName}-${environment}-assignment'
  policySetDefinition: '${resourcePrefix}-${workloadName}-${environment}-policyset'
}

// Built-in policy definition IDs for Azure Security Benchmark
var builtInPolicies = {
  azureSecurityBenchmark: '/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8'
  requireHttpsStorage: '/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9'
  requireSqlTde: '/providers/Microsoft.Authorization/policyDefinitions/17k78e20-9358-41c9-923c-fb736d382a12'
  requireKeyVaultSoftDelete: '/providers/Microsoft.Authorization/policyDefinitions/1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d'
  requireNsgOnSubnets: '/providers/Microsoft.Authorization/policyDefinitions/e71308d3-144b-4262-b144-efdc3cc90517'
  requirePrivateEndpoints: '/providers/Microsoft.Authorization/policyDefinitions/6edd7eda-6dd8-40f7-810d-67160c639cd9'
}

// Custom policy definition for Key Vault network access
resource keyVaultNetworkAccessPolicy 'Microsoft.Authorization/policyDefinitions@2023-04-01' = if (enableCustomPolicies) {
  name: '${namingConvention.policyDefinition}-keyvault-network'
  properties: {
    displayName: 'Key Vault should restrict network access'
    description: 'Key Vault should be configured to deny access from all networks by default and only allow access from specific virtual networks or IP addresses'
    policyType: 'Custom'
    mode: 'All'
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Audit'
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        metadata: {
          displayName: 'Effect'
          description: 'The effect determines what happens when the policy rule is evaluated to match'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.KeyVault/vaults'
          }
          {
            anyOf: [
              {
                field: 'Microsoft.KeyVault/vaults/networkAcls.defaultAction'
                notEquals: 'Deny'
              }
              {
                field: 'Microsoft.KeyVault/vaults/networkAcls'
                exists: false
              }
            ]
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

// Custom policy definition for Storage Account secure transfer
resource storageSecureTransferPolicy 'Microsoft.Authorization/policyDefinitions@2023-04-01' = if (enableCustomPolicies) {
  name: '${namingConvention.policyDefinition}-storage-secure'
  properties: {
    displayName: 'Storage accounts should enforce secure transfer and disable public access'
    description: 'Storage accounts should require secure transfer (HTTPS) and disable public blob access for enhanced security'
    policyType: 'Custom'
    mode: 'All'
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Audit'
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        metadata: {
          displayName: 'Effect'
          description: 'The effect determines what happens when the policy rule is evaluated to match'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Storage/storageAccounts'
          }
          {
            anyOf: [
              {
                field: 'Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly'
                notEquals: true
              }
              {
                field: 'Microsoft.Storage/storageAccounts/allowBlobPublicAccess'
                notEquals: false
              }
            ]
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

// Custom policy definition for SQL Database security
resource sqlDatabaseSecurityPolicy 'Microsoft.Authorization/policyDefinitions@2023-04-01' = if (enableCustomPolicies) {
  name: '${namingConvention.policyDefinition}-sql-security'
  properties: {
    displayName: 'SQL databases should have advanced security features enabled'
    description: 'SQL databases should have Transparent Data Encryption, Advanced Data Security, and Azure AD authentication enabled'
    policyType: 'Custom'
    mode: 'All'
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Audit'
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        metadata: {
          displayName: 'Effect'
          description: 'The effect determines what happens when the policy rule is evaluated to match'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Sql/servers/databases'
          }
          {
            field: 'name'
            notEquals: 'master'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

// Custom policy set definition combining organizational policies
resource organizationalPolicySet 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = if (enableCustomPolicies) {
  name: '${namingConvention.policySetDefinition}-organizational'
  properties: {
    displayName: 'Organizational Security and Compliance Policies'
    description: 'Custom policy set for organizational security and compliance requirements'
    policyType: 'Custom'
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Audit'
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        metadata: {
          displayName: 'Effect'
          description: 'The effect determines what happens when the policy rule is evaluated to match'
        }
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: keyVaultNetworkAccessPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
      {
        policyDefinitionId: storageSecureTransferPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
      {
        policyDefinitionId: sqlDatabaseSecurityPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
      {
        policyDefinitionId: networkSecurityPolicy.id
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
      {
        policyDefinitionId: builtInPolicies.requireHttpsStorage
        parameters: {}
      }
      {
        policyDefinitionId: builtInPolicies.requireSqlTde
        parameters: {}
      }
      {
        policyDefinitionId: builtInPolicies.requireKeyVaultSoftDelete
        parameters: {}
      }
      {
        policyDefinitionId: builtInPolicies.requireNsgOnSubnets
        parameters: {}
      }
      {
        policyDefinitionId: builtInPolicies.requirePrivateEndpoints
        parameters: {}
      }
    ]
  }
}

// Policy assignment for Azure Security Benchmark
resource securityBenchmarkAssignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = if (enableSecurityBenchmark) {
  name: '${namingConvention.policyAssignment}-security-benchmark'
  properties: {
    displayName: 'Azure Security Benchmark Assignment'
    description: 'Assignment of Azure Security Benchmark policies for compliance monitoring'
    policyDefinitionId: builtInPolicies.azureSecurityBenchmark
    parameters: {}
    enforcementMode: 'Default'
    metadata: {
      assignedBy: 'Bicep Template'
      category: 'Security'
    }
  }
}

// Policy assignment for organizational policies
resource organizationalPolicyAssignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = if (enableCustomPolicies) {
  name: '${namingConvention.policyAssignment}-organizational'
  properties: {
    displayName: 'Organizational Security Policies Assignment'
    description: 'Assignment of custom organizational security and compliance policies'
    policyDefinitionId: organizationalPolicySet.id
    parameters: {
      effect: {
        value: environment == 'prod' ? 'Deny' : 'Audit'
      }
    }
    enforcementMode: 'Default'
    metadata: {
      assignedBy: 'Bicep Template'
      category: 'Security'
      environment: environment
    }
  }
}

// Compliance reporting automation (Logic App for compliance notifications)
resource complianceReportingLogicApp 'Microsoft.Logic/workflows@2019-05-01' = if (!empty(complianceNotificationEmails)) {
  name: '${namingConvention.policyDefinition}-compliance-reporting'
  location: location
  tags: tags
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        recurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Day'
            interval: 1
            schedule: {
              hours: [
                8
              ]
              minutes: [
                0
              ]
            }
          }
        }
      }
      actions: {
        'Get-Policy-Compliance': {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: 'https://management.azure.com/subscriptions/${subscription().subscriptionId}/providers/Microsoft.PolicyInsights/policyStates/latest/summarize?api-version=2019-10-01'
            headers: {
              'Content-Type': 'application/json'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
        'Send-Compliance-Email': {
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/Mail'
            body: {
              To: join(complianceNotificationEmails, ';')
              Subject: 'Daily Policy Compliance Report - ${environment}'
              Body: 'Policy compliance summary for ${workloadName} in ${environment} environment.'
            }
          }
          runAfter: {
            'Get-Policy-Compliance': [
              'Succeeded'
            ]
          }
        }
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Additional policy definitions for enhanced compliance
resource networkSecurityPolicy 'Microsoft.Authorization/policyDefinitions@2023-04-01' = if (enableCustomPolicies) {
  name: '${namingConvention.policyDefinition}-network-security'
  properties: {
    displayName: 'Network Security Groups should be associated with subnets'
    description: 'All subnets should have Network Security Groups associated for enhanced security'
    policyType: 'Custom'
    mode: 'All'
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'Audit'
        allowedValues: [
          'Audit'
          'Deny'
          'Disabled'
        ]
        metadata: {
          displayName: 'Effect'
          description: 'The effect determines what happens when the policy rule is evaluated to match'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Network/virtualNetworks/subnets'
          }
          {
            field: 'Microsoft.Network/virtualNetworks/subnets/networkSecurityGroup'
            exists: false
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

resource diagnosticLoggingPolicy 'Microsoft.Authorization/policyDefinitions@2023-04-01' = if (enableCustomPolicies) {
  name: '${namingConvention.policyDefinition}-diagnostic-logging'
  properties: {
    displayName: 'Resources should have diagnostic settings enabled'
    description: 'All resources should have diagnostic settings configured to send logs to Log Analytics workspace'
    policyType: 'Custom'
    mode: 'All'
    parameters: {
      effect: {
        type: 'String'
        defaultValue: 'AuditIfNotExists'
        allowedValues: [
          'AuditIfNotExists'
          'DeployIfNotExists'
          'Disabled'
        ]
        metadata: {
          displayName: 'Effect'
          description: 'The effect determines what happens when the policy rule is evaluated to match'
        }
      }
      logAnalyticsWorkspaceId: {
        type: 'String'
        metadata: {
          displayName: 'Log Analytics Workspace ID'
          description: 'The Log Analytics workspace ID where diagnostic logs should be sent'
        }
      }
    }
    policyRule: {
      if: {
        field: 'type'
        in: [
          'Microsoft.KeyVault/vaults'
          'Microsoft.Storage/storageAccounts'
          'Microsoft.Sql/servers'
          'Microsoft.Network/applicationGateways'
          'Microsoft.Network/loadBalancers'
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Insights/diagnosticSettings'
          existenceCondition: {
            field: 'Microsoft.Insights/diagnosticSettings/workspaceId'
            equals: '[parameters(\'logAnalyticsWorkspaceId\')]'
          }
        }
      }
    }
  }
}

// Outputs
output policyDefinitionIds object = enableCustomPolicies ? {
  keyVaultNetworkAccess: keyVaultNetworkAccessPolicy.id
  storageSecureTransfer: storageSecureTransferPolicy.id
  sqlDatabaseSecurity: sqlDatabaseSecurityPolicy.id
  networkSecurity: networkSecurityPolicy.id
  diagnosticLogging: diagnosticLoggingPolicy.id
} : {}

output policySetDefinitionId string = enableCustomPolicies ? organizationalPolicySet.id : ''

output policyAssignmentIds object = {
  securityBenchmark: enableSecurityBenchmark ? securityBenchmarkAssignment.id : ''
  organizational: enableCustomPolicies ? organizationalPolicyAssignment.id : ''
}

output complianceReportingEnabled bool = !empty(complianceNotificationEmails)

output complianceReportingLogicAppId string = !empty(complianceNotificationEmails) ? complianceReportingLogicApp.id : ''

// Policy compliance status for monitoring
output policyComplianceStatus object = {
  securityBenchmarkEnabled: enableSecurityBenchmark
  customPoliciesEnabled: enableCustomPolicies
  complianceReportingConfigured: !empty(complianceNotificationEmails)
  policyScope: policyScope
  enforcementMode: environment == 'prod' ? 'Deny' : 'Audit'
}