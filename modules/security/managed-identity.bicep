// Managed Identity module
// This module creates system-assigned and user-assigned managed identities for Azure services

targetScope = 'resourceGroup'

// Import shared types
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

// Required parameters
@description('The base name for managed identities')
param managedIdentityBaseName string

@description('The Azure region for deployment')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags TagConfiguration

// Configuration parameters
@description('List of user-assigned managed identities to create')
param userAssignedIdentities array = [
  {
    name: 'application-services'
    description: 'Managed identity for application services'
    roleAssignments: []
  }
  {
    name: 'key-vault-access'
    description: 'Managed identity for Key Vault access'
    roleAssignments: []
  }
  {
    name: 'storage-access'
    description: 'Managed identity for storage account access'
    roleAssignments: []
  }
  {
    name: 'sql-access'
    description: 'Managed identity for SQL database access'
    roleAssignments: []
  }
]

@description('Enable diagnostic settings for managed identities')
param enableDiagnostics bool = true

@description('Log Analytics workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string = ''

@description('Enable telemetry for the module')
param enableTelemetry bool = true

// Variables
var identityNames = [for identity in userAssignedIdentities: '${managedIdentityBaseName}-${identity.name}-mi']

// Built-in role definitions commonly used with managed identities
var commonRoleDefinitions = {
  // Storage roles
  storageBlobDataContributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  storageBlobDataReader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
  storageAccountContributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
  
  // Key Vault roles
  keyVaultSecretsUser: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  keyVaultCertificateUser: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba')
  keyVaultCryptoUser: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '12338af0-0e69-4776-bea7-57ae8d297424')
  
  // SQL roles
  sqlDbContributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec')
  
  // Monitoring roles
  monitoringContributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '749f88d5-cbae-40b8-bcfc-e573ddc772fa')
  monitoringReader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '43d0d8ad-25c7-4714-9337-8ba259a9fe05')
  
  // General roles
  contributor: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  reader: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
}

// Create user-assigned managed identities
resource userAssignedManagedIdentities 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [for (identity, i) in userAssignedIdentities: {
  name: identityNames[i]
  location: location
  tags: union(tags, {
    Purpose: identity.description
    IdentityType: 'UserAssigned'
  })
}]

// Create role assignments for managed identities (if specified)
resource managedIdentityRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (identity, identityIndex) in userAssignedIdentities: if (!empty(identity.roleAssignments)) {
  name: guid(userAssignedManagedIdentities[identityIndex].id, identity.name, 'role-assignment')
  properties: {
    roleDefinitionId: commonRoleDefinitions[identity.roleAssignments[0].role] // Simplified for first role
    principalId: userAssignedManagedIdentities[identityIndex].properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

// Diagnostic settings for managed identities (if Log Analytics workspace is provided)
resource managedIdentityDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (identity, i) in userAssignedIdentities: if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${identityNames[i]}-diagnostics'
  scope: userAssignedManagedIdentities[i]
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}]

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
@description('Array of user-assigned managed identity resource IDs')
output managedIdentityIds array = [for i in range(0, length(userAssignedIdentities)): userAssignedManagedIdentities[i].id]

@description('Array of user-assigned managed identity names')
output managedIdentityNames array = [for i in range(0, length(userAssignedIdentities)): userAssignedManagedIdentities[i].name]

@description('Array of user-assigned managed identity principal IDs')
output managedIdentityPrincipalIds array = [for i in range(0, length(userAssignedIdentities)): userAssignedManagedIdentities[i].properties.principalId]

@description('Array of user-assigned managed identity client IDs')
output managedIdentityClientIds array = [for i in range(0, length(userAssignedIdentities)): userAssignedManagedIdentities[i].properties.clientId]

@description('Managed identity configuration details')
output managedIdentityConfigs array = [for (identity, i) in userAssignedIdentities: {
  name: userAssignedManagedIdentities[i].name
  id: userAssignedManagedIdentities[i].id
  principalId: userAssignedManagedIdentities[i].properties.principalId
  clientId: userAssignedManagedIdentities[i].properties.clientId
  purpose: identity.description
  type: 'UserAssigned'
}]

@description('Managed identity lookup object for easy reference')
output managedIdentityLookup object = {
  applicationServices: {
    id: userAssignedManagedIdentities[0].id
    principalId: userAssignedManagedIdentities[0].properties.principalId
    clientId: userAssignedManagedIdentities[0].properties.clientId
  }
  keyVaultAccess: {
    id: userAssignedManagedIdentities[1].id
    principalId: userAssignedManagedIdentities[1].properties.principalId
    clientId: userAssignedManagedIdentities[1].properties.clientId
  }
  storageAccess: {
    id: userAssignedManagedIdentities[2].id
    principalId: userAssignedManagedIdentities[2].properties.principalId
    clientId: userAssignedManagedIdentities[2].properties.clientId
  }
  sqlAccess: {
    id: userAssignedManagedIdentities[3].id
    principalId: userAssignedManagedIdentities[3].properties.principalId
    clientId: userAssignedManagedIdentities[3].properties.clientId
  }
}

@description('Common role definitions for reference')
output roleDefinitions object = commonRoleDefinitions