// Key Vault module
// This module implements Key Vault with RBAC and access policies for secure secret management

targetScope = 'resourceGroup'

// Import shared types
import { KeyVaultConfig, TagConfiguration } from '../shared/parameter-schemas.bicep'

// Required parameters
@description('The name of the Key Vault')
param keyVaultName string

@description('The Azure region for deployment')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags TagConfiguration

// Key Vault configuration parameters
@description('Key Vault configuration settings')
param keyVaultConfig KeyVaultConfig = {
  sku: 'standard'
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

// Optional parameters
@description('Subnet IDs that should have access to Key Vault')
param allowedSubnetIds string[] = []

@description('IP addresses that should have access to Key Vault')
param allowedIpAddresses string[] = []

@description('Object IDs of users/groups/service principals that should have Key Vault Administrator access')
param keyVaultAdministrators string[] = []

@description('Object IDs of users/groups/service principals that should have Key Vault Secrets User access')
param keyVaultSecretsUsers string[] = []

@description('Object IDs of users/groups/service principals that should have Key Vault Certificate User access')
param keyVaultCertificateUsers string[] = []

@description('Enable diagnostic settings for Key Vault')
param enableDiagnostics bool = true

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string = ''

@description('Enable telemetry for the module')
param enableTelemetry bool = true

// Variables
var ipRules = [for ip in allowedIpAddresses: {
  value: ip
}]

var virtualNetworkRules = [for subnetId in allowedSubnetIds: {
  id: subnetId
  ignoreMissingVnetServiceEndpoint: false
}]

var networkRules = {
  bypass: keyVaultConfig.networkAcls.bypass
  defaultAction: keyVaultConfig.networkAcls.defaultAction
  ipRules: ipRules
  virtualNetworkRules: virtualNetworkRules
}

// Built-in role definitions for Key Vault
var roleDefinitions = {
  keyVaultAdministrator: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
  keyVaultSecretsUser: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  keyVaultCertificateUser: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba')
  keyVaultCryptoUser: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '12338af0-0e69-4776-bea7-57ae8d297424')
}

// Deploy Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: keyVaultConfig.sku
    }
    tenantId: tenant().tenantId
    enableSoftDelete: keyVaultConfig.enableSoftDelete
    softDeleteRetentionInDays: keyVaultConfig.softDeleteRetentionInDays
    enablePurgeProtection: keyVaultConfig.enablePurgeProtection ? true : null
    enableRbacAuthorization: keyVaultConfig.enableRbacAuthorization
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    networkAcls: networkRules
    publicNetworkAccess: keyVaultConfig.networkAcls.defaultAction == 'Allow' ? 'Enabled' : 'Disabled'
  }
}

// Role assignments for Key Vault Administrators
resource keyVaultAdminRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultAdministrators: {
  name: guid(keyVault.id, principalId, roleDefinitions.keyVaultAdministrator)
  scope: keyVault
  properties: {
    roleDefinitionId: roleDefinitions.keyVaultAdministrator
    principalId: principalId
    principalType: 'User'
  }
}]

// Role assignments for Key Vault Secrets Users
resource keyVaultSecretsUserRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultSecretsUsers: {
  name: guid(keyVault.id, principalId, roleDefinitions.keyVaultSecretsUser)
  scope: keyVault
  properties: {
    roleDefinitionId: roleDefinitions.keyVaultSecretsUser
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]

// Role assignments for Key Vault Certificate Users
resource keyVaultCertificateUserRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in keyVaultCertificateUsers: {
  name: guid(keyVault.id, principalId, roleDefinitions.keyVaultCertificateUser)
  scope: keyVault
  properties: {
    roleDefinitionId: roleDefinitions.keyVaultCertificateUser
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]

// Diagnostic settings for Key Vault
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Telemetry deployment (optional)
resource telemetryDeployment 'Microsoft.Resources/deployments@2022-09-01' = if (enableTelemetry) {
  name: 'pid-47ed15a6-730a-4827-bcb4-0fd963ffbd82-${uniqueString(deployment().name, location)}'
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      resources: []
    }
  }
}

// Outputs
@description('The resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('The name of the Key Vault')
output keyVaultName string = keyVault.name

@description('The URI of the Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri

@description('The Key Vault configuration')
output keyVaultConfig object = {
  id: keyVault.id
  name: keyVault.name
  uri: keyVault.properties.vaultUri
  sku: keyVault.properties.sku.name
  enableSoftDelete: keyVault.properties.enableSoftDelete
  softDeleteRetentionInDays: keyVault.properties.softDeleteRetentionInDays
  enablePurgeProtection: keyVault.properties.enablePurgeProtection
  enableRbacAuthorization: keyVault.properties.enableRbacAuthorization
  networkAcls: keyVault.properties.networkAcls
  publicNetworkAccess: keyVault.properties.publicNetworkAccess
}

@description('Role assignment information')
output roleAssignments object = {
  administratorsCount: length(keyVaultAdministrators)
  secretsUsersCount: length(keyVaultSecretsUsers)
  certificateUsersCount: length(keyVaultCertificateUsers)
  roleDefinitions: roleDefinitions
}