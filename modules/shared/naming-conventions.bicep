// Naming convention utilities for consistent resource naming
// This module provides standardized naming patterns for all Azure resources
//
// Usage Examples:
// 1. Import the module:
//    module naming 'modules/shared/naming-conventions.bicep' = {
//      name: 'naming-conventions'
//      params: {
//        resourcePrefix: 'contoso'
//        environment: 'prod'
//        workloadName: 'webapp'
//      }
//    }
//
// 2. Use naming convention:
//    name: naming.outputs.namingConvention.virtualNetwork
//
// 3. Use pre-computed names:
//    name: naming.outputs.subnetNames.webTier
//    name: naming.outputs.specializedNames.keyVault
//
// Naming Pattern: {resourcePrefix}-{workloadName}-{environment}-{resourceType}{suffix}
// Example: contoso-webapp-prod-vnet

@description('The prefix for all resource names')
@minLength(2)
@maxLength(10)
param resourcePrefix string

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('The workload or application name')
@minLength(2)
@maxLength(15)
param workloadName string

@description('Optional suffix for resource differentiation')
@maxLength(5)
param suffix string = ''

// Azure resource naming length limits
var namingLimits = {
  resourceGroup: 90
  virtualNetwork: 64
  subnet: 80
  networkSecurityGroup: 80
  applicationGateway: 80
  loadBalancer: 80
  keyVault: 24
  storageAccount: 24
  sqlServer: 63
  virtualMachine: 64
  logAnalyticsWorkspace: 63
}

// Helper function to validate name length
func validateNameLength(name string, resourceType string) string => length(name) <= namingLimits[resourceType] ? name : take(name, namingLimits[resourceType])

// Generate naming convention object with all resource types
var namingConvention = {
  // Resource Groups
  resourceGroup: '${resourcePrefix}-${workloadName}-${environment}-rg${suffix}'
  
  // Networking Resources
  virtualNetwork: '${resourcePrefix}-${workloadName}-${environment}-vnet${suffix}'
  subnet: '${resourcePrefix}-${workloadName}-${environment}-{subnetType}-snet${suffix}'
  networkSecurityGroup: '${resourcePrefix}-${workloadName}-${environment}-{subnetType}-nsg${suffix}'
  routeTable: '${resourcePrefix}-${workloadName}-${environment}-{subnetType}-rt${suffix}'
  publicIp: '${resourcePrefix}-${workloadName}-${environment}-{purpose}-pip${suffix}'
  networkInterface: '${resourcePrefix}-${workloadName}-${environment}-{vmName}-nic${suffix}'
  virtualNetworkGateway: '${resourcePrefix}-${workloadName}-${environment}-vgw${suffix}'
  localNetworkGateway: '${resourcePrefix}-${workloadName}-${environment}-lgw${suffix}'
  
  // Virtual Network Manager
  virtualNetworkManager: '${resourcePrefix}-${workloadName}-${environment}-vnm${suffix}'
  networkGroup: '${resourcePrefix}-${workloadName}-${environment}-{groupType}-ng${suffix}'
  
  // Load Balancing
  applicationGateway: '${resourcePrefix}-${workloadName}-${environment}-agw${suffix}'
  loadBalancer: '${resourcePrefix}-${workloadName}-${environment}-{tier}-lb${suffix}'
  
  // Security Resources
  keyVault: take('${toLower(resourcePrefix)}${toLower(workloadName)}${toLower(environment)}kv${toLower(suffix)}', 24) // No hyphens, max 24 chars
  managedIdentity: '${resourcePrefix}-${workloadName}-${environment}-{purpose}-mi${suffix}'
  
  // Compute Resources
  virtualMachine: '${resourcePrefix}-${workloadName}-${environment}-{tier}-vm${suffix}'
  virtualMachineScaleSet: '${resourcePrefix}-${workloadName}-${environment}-{tier}-vmss${suffix}'
  availabilitySet: '${resourcePrefix}-${workloadName}-${environment}-{tier}-as${suffix}'
  
  // Storage Resources
  storageAccount: take('${toLower(resourcePrefix)}${toLower(workloadName)}${toLower(environment)}sa${toLower(suffix)}', 24) // No hyphens, lowercase only, max 24 chars
  
  // Database Resources
  sqlServer: '${resourcePrefix}-${workloadName}-${environment}-sql${suffix}'
  sqlDatabase: '${resourcePrefix}-${workloadName}-${environment}-{dbName}-sqldb${suffix}'
  
  // Monitoring Resources
  logAnalyticsWorkspace: '${resourcePrefix}-${workloadName}-${environment}-law${suffix}'
  applicationInsights: '${resourcePrefix}-${workloadName}-${environment}-ai${suffix}'
  actionGroup: '${resourcePrefix}-${workloadName}-${environment}-{alertType}-ag${suffix}'
  
  // Private Endpoints
  privateEndpoint: '${resourcePrefix}-${workloadName}-${environment}-{serviceName}-pe${suffix}'
  privateDnsZone: '${resourcePrefix}-${workloadName}-${environment}-{serviceName}-pdz${suffix}'
}

// Helper functions with validation and length checking
func getSubnetName(subnetType string) string => validateNameLength(replace(namingConvention.subnet, '{subnetType}', subnetType), 'subnet')

func getNsgName(subnetType string) string => validateNameLength(replace(namingConvention.networkSecurityGroup, '{subnetType}', subnetType), 'networkSecurityGroup')

func getLoadBalancerName(tier string) string => validateNameLength(replace(namingConvention.loadBalancer, '{tier}', tier), 'loadBalancer')

func getVmName(tier string) string => validateNameLength(replace(namingConvention.virtualMachine, '{tier}', tier), 'virtualMachine')

func getVmssName(tier string) string => validateNameLength(replace(namingConvention.virtualMachineScaleSet, '{tier}', tier), 'virtualMachine')

func getManagedIdentityName(purpose string) string => validateNameLength(replace(namingConvention.managedIdentity, '{purpose}', purpose), 'virtualNetwork')

func getPrivateEndpointName(serviceName string) string => validateNameLength(replace(namingConvention.privateEndpoint, '{serviceName}', serviceName), 'virtualNetwork')

func getNetworkGroupName(groupType string) string => validateNameLength(replace(namingConvention.networkGroup, '{groupType}', groupType), 'virtualNetwork')

// Specialized functions for resources with unique naming requirements
func getKeyVaultName() string => namingConvention.keyVault

func getStorageAccountName() string => namingConvention.storageAccount

func getSqlDatabaseName(dbName string) string => validateNameLength(replace(namingConvention.sqlDatabase, '{dbName}', dbName), 'sqlServer')

func getActionGroupName(alertType string) string => validateNameLength(replace(namingConvention.actionGroup, '{alertType}', alertType), 'virtualNetwork')

// Output the naming convention object and helper function results
output namingConvention object = namingConvention

// Output helper function results for common use cases
output subnetNames object = {
  applicationGateway: getSubnetName('agw')
  management: getSubnetName('mgmt')
  webTier: getSubnetName('web')
  businessTier: getSubnetName('biz')
  dataTier: getSubnetName('data')
  activeDirectory: getSubnetName('ad')
}

output nsgNames object = {
  applicationGateway: getNsgName('agw')
  management: getNsgName('mgmt')
  webTier: getNsgName('web')
  businessTier: getNsgName('biz')
  dataTier: getNsgName('data')
  activeDirectory: getNsgName('ad')
}

output loadBalancerNames object = {
  web: getLoadBalancerName('web')
  business: getLoadBalancerName('biz')
  data: getLoadBalancerName('data')
}

output specializedNames object = {
  keyVault: getKeyVaultName()
  storageAccount: getStorageAccountName()
}