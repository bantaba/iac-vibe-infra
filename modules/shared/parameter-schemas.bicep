// Common parameter schemas and type definitions
// This module defines reusable parameter types and validation schemas

// Environment configuration schema
@export()
type EnvironmentConfig = {
  @description('Service tier for the environment (Basic, Standard, Premium)')
  skuTier: 'Basic' | 'Standard' | 'Premium'
  
  @description('Default instance count for scalable resources')
  instanceCount: int
  
  @description('Enable high availability features')
  enableHighAvailability: bool
  
  @description('Enable DDoS protection')
  enableDdosProtection: bool
  
  @description('SQL Database SKU')
  sqlDatabaseSku: 'Basic' | 'S0' | 'S1' | 'S2' | 'S3' | 'P1' | 'P2' | 'P4' | 'P6' | 'GP_Gen5_2' | 'GP_Gen5_4' | 'BC_Gen5_2' | 'BC_Gen5_4'
  
  @description('Storage Account SKU')
  storageAccountSku: 'Standard_LRS' | 'Standard_GRS' | 'Standard_ZRS' | 'Premium_LRS' | 'Premium_ZRS'
  
  @description('Application Gateway SKU')
  applicationGatewaySku: 'Standard_v2' | 'WAF_v2'
  
  @description('Application Gateway capacity')
  @minValue(1)
  @maxValue(125)
  applicationGatewayCapacity: int
  
  @description('Virtual Machine size')
  virtualMachineSize: string
  
  @description('Enable backup for resources')
  enableBackup: bool
  
  @description('Log retention period in days')
  @minValue(30)
  @maxValue(730)
  logRetentionDays: int
  
  @description('Enable private endpoints for data services')
  enablePrivateEndpoints: bool
  
  @description('Network address space for the virtual network')
  networkAddressSpace: string
  
  @description('Subnet configuration')
  subnets: SubnetConfiguration
}

// Subnet configuration schema
@export()
type SubnetConfiguration = {
  @description('Application Gateway subnet address prefix')
  applicationGateway: string
  
  @description('Management subnet address prefix')
  management: string
  
  @description('Web tier subnet address prefix')
  webTier: string
  
  @description('Business tier subnet address prefix')
  businessTier: string
  
  @description('Data tier subnet address prefix')
  dataTier: string
  
  @description('Active Directory subnet address prefix')
  activeDirectory: string
}

// Network Security Group rule schema
@export()
type NsgRuleConfig = {
  @description('Rule name')
  name: string
  
  @description('Rule priority')
  @minValue(100)
  @maxValue(4096)
  priority: int
  
  @description('Rule direction')
  direction: 'Inbound' | 'Outbound'
  
  @description('Rule access')
  access: 'Allow' | 'Deny'
  
  @description('Rule protocol')
  protocol: 'Tcp' | 'Udp' | 'Icmp' | '*'
  
  @description('Source port range')
  sourcePortRange: string
  
  @description('Destination port range')
  destinationPortRange: string
  
  @description('Source address prefix')
  sourceAddressPrefix: string
  
  @description('Destination address prefix')
  destinationAddressPrefix: string
  
  @description('Rule description')
  description: string
}

// Load balancer configuration schema
@export()
type LoadBalancerConfig = {
  @description('Load balancer name')
  name: string
  
  @description('Load balancer SKU')
  sku: 'Basic' | 'Standard'
  
  @description('Frontend IP configuration')
  frontendIpConfiguration: {
    name: string
    privateIpAddress: string?
    privateIpAllocationMethod: 'Static' | 'Dynamic'
    subnetId: string?
    publicIpAddressId: string?
  }
  
  @description('Backend address pools')
  backendAddressPools: {
    name: string
  }[]
  
  @description('Load balancing rules')
  loadBalancingRules: {
    name: string
    frontendPort: int
    backendPort: int
    protocol: 'Tcp' | 'Udp'
    enableFloatingIp: bool
    idleTimeoutInMinutes: int
    loadDistribution: 'Default' | 'SourceIP' | 'SourceIPProtocol'
  }[]
  
  @description('Health probes')
  probes: {
    name: string
    protocol: 'Http' | 'Https' | 'Tcp'
    port: int
    requestPath: string?
    intervalInSeconds: int
    numberOfProbes: int
  }[]
}

// Key Vault configuration schema
@export()
type KeyVaultConfig = {
  @description('Key Vault SKU')
  sku: 'standard' | 'premium'
  
  @description('Enable soft delete')
  enableSoftDelete: bool
  
  @description('Soft delete retention days')
  @minValue(7)
  @maxValue(90)
  softDeleteRetentionInDays: int
  
  @description('Enable purge protection')
  enablePurgeProtection: bool
  
  @description('Enable RBAC authorization')
  enableRbacAuthorization: bool
  
  @description('Network access control')
  networkAcls: {
    bypass: 'AzureServices' | 'None'
    defaultAction: 'Allow' | 'Deny'
    ipRules: string[]?
    virtualNetworkRules: string[]?
  }
}

// Virtual Machine configuration schema
@export()
type VirtualMachineConfig = {
  @description('VM size')
  vmSize: string
  
  @description('Operating system type')
  osType: 'Windows' | 'Linux'
  
  @description('OS disk configuration')
  osDisk: {
    storageAccountType: 'Standard_LRS' | 'Premium_LRS' | 'StandardSSD_LRS'
    diskSizeGB: int?
  }
  
  @description('Data disk configurations')
  dataDisks: {
    diskSizeGB: int
    storageAccountType: 'Standard_LRS' | 'Premium_LRS' | 'StandardSSD_LRS'
    lun: int
  }[]?
  
  @description('Network interface configuration')
  networkInterface: {
    enableAcceleratedNetworking: bool
    enableIpForwarding: bool
  }
  
  @description('Availability configuration')
  availability: {
    availabilitySetId: string?
    availabilityZone: string?
  }
}

// Common tag schema
@export()
type TagConfiguration = {
  @description('Environment tag')
  Environment: string
  
  @description('Workload tag')
  Workload: string
  
  @description('Managed by tag')
  ManagedBy: string
  
  @description('Cost center tag')
  CostCenter: string
  
  @description('Owner tag')
  Owner: string?
  
  @description('Project tag')
  Project: string?
  
  @description('Deployment date tag')
  DeploymentDate: string?
}