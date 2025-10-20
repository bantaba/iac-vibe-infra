// Main orchestration template for Azure Bicep Infrastructure
// This template coordinates the deployment of all infrastructure modules

targetScope = 'resourceGroup'

// Import shared modules
import { EnvironmentConfig, TagConfiguration } from 'modules/shared/parameter-schemas.bicep'

// Common parameters
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
param tags TagConfiguration = {
  Environment: environment
  Workload: workloadName
  ManagedBy: 'Bicep'
  CostCenter: 'IT'
  DeployedBy: 'Azure-Bicep-Infrastructure'
  DeploymentDate: utcNow('yyyy-MM-dd')
}

// Environment-specific configuration
@description('Environment-specific configuration settings')
param environmentConfig EnvironmentConfig

// Deploy naming convention utilities
module namingConventions 'modules/shared/naming-conventions.bicep' = {
  name: 'naming-conventions'
  params: {
    resourcePrefix: resourcePrefix
    environment: environment
    workloadName: workloadName
  }
}

// Deploy common variables and constants
module commonVariables 'modules/shared/common-variables.bicep' = {
  name: 'common-variables'
}

// Module deployments will be added in subsequent tasks
// This main template serves as the orchestration point for all infrastructure components

// Outputs
output namingConvention object = namingConventions.outputs.namingConvention
output deploymentTags TagConfiguration = tags
output environmentConfig EnvironmentConfig = environmentConfig
output commonVariables object = commonVariables.outputs
output resourcePrefix string = resourcePrefix
output environment string = environment
output workloadName string = workloadName
output location string = location