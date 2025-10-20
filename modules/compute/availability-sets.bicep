// Availability Sets module
// This module creates availability sets and fault domains for high availability
// Supports both availability sets and proximity placement groups for optimal VM placement

targetScope = 'resourceGroup'

// Import shared modules
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

@description('The name of the availability set')
param availabilitySetName string

@description('The tier for this availability set (web, business, or data)')
@allowed(['web', 'business', 'data'])
param tier string

@description('Number of fault domains')
@minValue(1)
@maxValue(3)
param faultDomainCount int = 3

@description('Number of update domains')
@minValue(1)
@maxValue(20)
param updateDomainCount int = 5

@description('Use managed disks (recommended)')
param useManagedDisks bool = true

@description('Create proximity placement group for low latency')
param createProximityPlacementGroup bool = false

@description('Proximity placement group type')
@allowed(['Standard', 'Ultra'])
param proximityPlacementGroupType string = 'Standard'

@description('Tags to apply to all resources')
param tags TagConfiguration

@description('Location for the availability set')
param location string = resourceGroup().location

// Proximity Placement Group (optional)
resource proximityPlacementGroup 'Microsoft.Compute/proximityPlacementGroups@2023-09-01' = if (createProximityPlacementGroup) {
  name: '${availabilitySetName}-ppg'
  location: location
  tags: tags
  properties: {
    proximityPlacementGroupType: proximityPlacementGroupType
  }
}

// Availability Set resource
resource availabilitySet 'Microsoft.Compute/availabilitySets@2023-09-01' = {
  name: availabilitySetName
  location: location
  tags: tags
  sku: {
    name: useManagedDisks ? 'Aligned' : 'Classic'
  }
  properties: {
    platformFaultDomainCount: faultDomainCount
    platformUpdateDomainCount: updateDomainCount
    proximityPlacementGroup: createProximityPlacementGroup ? {
      id: proximityPlacementGroup.id
    } : null
  }
}

// Outputs
@description('The resource ID of the availability set')
output availabilitySetId string = availabilitySet.id

@description('The name of the availability set')
output availabilitySetName string = availabilitySet.name

@description('The resource ID of the proximity placement group (if created)')
output proximityPlacementGroupId string = createProximityPlacementGroup ? proximityPlacementGroup.id : ''

@description('The availability set configuration details')
output availabilitySetConfig object = {
  resourceId: availabilitySet.id
  name: availabilitySet.name
  tier: tier
  faultDomainCount: faultDomainCount
  updateDomainCount: updateDomainCount
  useManagedDisks: useManagedDisks
  proximityPlacementGroupEnabled: createProximityPlacementGroup
  proximityPlacementGroupId: createProximityPlacementGroup ? proximityPlacementGroup.id : ''
}