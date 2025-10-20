// Internal Load Balancer module
// This module creates internal load balancers for business and data tiers
// Supports health probes, load balancing rules, and high availability configurations

targetScope = 'resourceGroup'

// Import shared modules
import { TagConfiguration, LoadBalancerConfig } from '../shared/parameter-schemas.bicep'

@description('The name of the load balancer')
param loadBalancerName string

@description('The SKU of the load balancer')
@allowed(['Basic', 'Standard'])
param sku string = 'Standard'

@description('The subnet ID for the load balancer frontend IP')
param subnetId string

@description('The private IP address for the load balancer (optional, will use dynamic if not specified)')
param privateIpAddress string?

@description('The private IP allocation method')
@allowed(['Static', 'Dynamic'])
param privateIpAllocationMethod string = 'Dynamic'

@description('The tier for this load balancer (business or data)')
@allowed(['business', 'data'])
param tier string

@description('Backend address pool configurations')
param backendAddressPools array = [
  {
    name: '${tier}-tier-pool'
  }
]

@description('Load balancing rules configurations')
param loadBalancingRules array = [
  {
    name: '${tier}-tier-http-rule'
    frontendPort: 80
    backendPort: 80
    protocol: 'Tcp'
    enableFloatingIp: false
    idleTimeoutInMinutes: 4
    loadDistribution: 'Default'
    probeName: '${tier}-tier-http-probe'
  }
  {
    name: '${tier}-tier-https-rule'
    frontendPort: 443
    backendPort: 443
    protocol: 'Tcp'
    enableFloatingIp: false
    idleTimeoutInMinutes: 4
    loadDistribution: 'Default'
    probeName: '${tier}-tier-https-probe'
  }
]

@description('Health probe configurations')
param healthProbes array = [
  {
    name: '${tier}-tier-http-probe'
    protocol: 'Http'
    port: 80
    requestPath: '/health'
    intervalInSeconds: 15
    numberOfProbes: 2
  }
  {
    name: '${tier}-tier-https-probe'
    protocol: 'Https'
    port: 443
    requestPath: '/health'
    intervalInSeconds: 15
    numberOfProbes: 2
  }
  {
    name: '${tier}-tier-tcp-probe'
    protocol: 'Tcp'
    port: 1433
    intervalInSeconds: 15
    numberOfProbes: 2
  }
]

@description('Inbound NAT rules configurations (optional)')
param inboundNatRules array = []

@description('Outbound rules configurations (optional)')
param outboundRules array = []

@description('Enable TCP reset for idle timeout')
param enableTcpReset bool = true

@description('Enable floating IP for SQL Always On scenarios')
param enableFloatingIp bool = false

@description('Tags to apply to all resources')
param tags TagConfiguration

@description('Location for the load balancer')
param location string = resourceGroup().location

@description('Availability zones for the load balancer (Standard SKU only)')
param zones array = ['1', '2', '3']

// Variables for resource configuration
var frontendIpConfigurationName = '${tier}-tier-frontend-ip'

var frontendIpConfigurations = [
  {
    name: frontendIpConfigurationName
    properties: {
      subnet: {
        id: subnetId
      }
      privateIPAddress: privateIpAddress
      privateIPAllocationMethod: privateIpAllocationMethod
    }
  }
]

var backendAddressPoolsCollection = [for pool in backendAddressPools: {
  name: pool.name
  properties: {}
}]

var probesCollection = [for probe in healthProbes: {
  name: probe.name
  properties: {
    protocol: probe.protocol
    port: probe.port
    requestPath: (probe.protocol == 'Http' || probe.protocol == 'Https') ? probe.requestPath : null
    intervalInSeconds: probe.intervalInSeconds
    numberOfProbes: probe.numberOfProbes
  }
}]

var loadBalancingRulesCollection = [for rule in loadBalancingRules: {
  name: rule.name
  properties: {
    frontendIPConfiguration: {
      id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, frontendIpConfigurationName)
    }
    backendAddressPool: {
      id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, backendAddressPools[0].name)
    }
    probe: contains(rule, 'probeName') ? {
      id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, rule.probeName)
    } : null
    protocol: rule.protocol
    frontendPort: rule.frontendPort
    backendPort: rule.backendPort
    enableFloatingIP: rule.enableFloatingIp
    idleTimeoutInMinutes: rule.idleTimeoutInMinutes
    loadDistribution: rule.loadDistribution
    enableTcpReset: enableTcpReset
  }
}]

var inboundNatRulesCollection = [for rule in inboundNatRules: {
  name: rule.name
  properties: {
    frontendIPConfiguration: {
      id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, frontendIpConfigurationName)
    }
    protocol: rule.protocol
    frontendPort: rule.frontendPort
    backendPort: rule.backendPort
    enableFloatingIP: enableFloatingIp
    idleTimeoutInMinutes: contains(rule, 'idleTimeoutInMinutes') ? rule.idleTimeoutInMinutes : 4
    enableTcpReset: enableTcpReset
  }
}]

var outboundRulesCollection = [for rule in outboundRules: {
  name: rule.name
  properties: {
    frontendIPConfigurations: [
      {
        id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, frontendIpConfigurationName)
      }
    ]
    backendAddressPool: {
      id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, backendAddressPools[0].name)
    }
    protocol: rule.protocol
    allocatedOutboundPorts: contains(rule, 'allocatedOutboundPorts') ? rule.allocatedOutboundPorts : 1024
    idleTimeoutInMinutes: contains(rule, 'idleTimeoutInMinutes') ? rule.idleTimeoutInMinutes : 4
    enableTcpReset: enableTcpReset
  }
}]

// Load Balancer resource
resource loadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: loadBalancerName
  location: location
  tags: tags
  sku: {
    name: sku
    tier: 'Regional'
  }
  zones: (sku == 'Standard') ? zones : null
  properties: {
    frontendIPConfigurations: frontendIpConfigurations
    backendAddressPools: backendAddressPoolsCollection
    loadBalancingRules: loadBalancingRulesCollection
    probes: probesCollection
    inboundNatRules: inboundNatRulesCollection
    outboundRules: (sku == 'Standard') ? outboundRulesCollection : []
  }
}

// Outputs
@description('The resource ID of the load balancer')
output loadBalancerId string = loadBalancer.id

@description('The name of the load balancer')
output loadBalancerName string = loadBalancer.name

@description('The private IP address of the load balancer')
output privateIpAddress string = loadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress

@description('The frontend IP configuration resource ID')
output frontendIpConfigurationId string = resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, frontendIpConfigurationName)

@description('The backend address pool resource IDs')
output backendAddressPoolIds object = reduce(backendAddressPools, {}, (cur, pool) => union(cur, {
  '${pool.name}': resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, pool.name)
}))

@description('The health probe resource IDs')
output healthProbeIds object = reduce(healthProbes, {}, (cur, probe) => union(cur, {
  '${probe.name}': resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, probe.name)
}))

@description('The load balancer configuration details')
output loadBalancerConfig object = {
  resourceId: loadBalancer.id
  name: loadBalancer.name
  sku: sku
  tier: tier
  privateIpAddress: loadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress
  backendPools: map(backendAddressPools, pool => pool.name)
  healthProbes: map(healthProbes, probe => probe.name)
  loadBalancingRules: map(loadBalancingRules, rule => rule.name)
}