// Virtual Machine Scale Sets module
// This module creates VM scale sets across availability zones with auto-scaling capabilities
// Supports Windows and Linux VMs with managed disks and network security

targetScope = 'resourceGroup'

// Import shared modules
import { TagConfiguration, VirtualMachineConfig } from '../shared/parameter-schemas.bicep'

@description('The name prefix for the VM scale set')
param vmScaleSetName string

@description('The subnet ID for the VM scale set')
param subnetId string

@description('The load balancer backend address pool IDs (optional)')
param loadBalancerBackendAddressPoolIds array = []

@description('The application gateway backend address pool IDs (optional)')
param applicationGatewayBackendAddressPoolIds array = []

@description('VM configuration')
param vmConfig VirtualMachineConfig

@description('The tier for this VM scale set (web, business, or data)')
@allowed(['web', 'business', 'data'])
param tier string

@description('Initial instance count for the scale set')
@minValue(0)
@maxValue(1000)
param instanceCount int = 2

@description('Enable autoscaling')
param enableAutoscaling bool = true

@description('Minimum instance count for autoscaling')
@minValue(1)
@maxValue(1000)
param minInstanceCount int = 1

@description('Maximum instance count for autoscaling')
@minValue(1)
@maxValue(1000)
param maxInstanceCount int = 10

@description('Availability zones for the scale set')
param availabilityZones array = ['1', '2', '3']

@description('Admin username for the VMs')
param adminUsername string

@description('Admin password for Windows VMs (use Key Vault reference)')
@secure()
param adminPassword string?

@description('SSH public key for Linux VMs')
param sshPublicKey string?

@description('Custom script extension settings (optional)')
param customScriptExtension object = {}

@description('Enable boot diagnostics')
param enableBootDiagnostics bool = true

@description('Storage account URI for boot diagnostics (optional)')
param bootDiagnosticsStorageUri string?

@description('Network security group ID for the network interface')
param networkSecurityGroupId string?

@description('Enable accelerated networking')
param enableAcceleratedNetworking bool = true

@description('Enable IP forwarding')
param enableIpForwarding bool = false

@description('Tags to apply to all resources')
param tags TagConfiguration

@description('Location for the VM scale set')
param location string = resourceGroup().location

@description('Upgrade policy mode')
@allowed(['Automatic', 'Manual', 'Rolling'])
param upgradeMode string = 'Manual'

@description('Enable single placement group')
param singlePlacementGroup bool = true

@description('Enable over-provisioning')
param overprovision bool = true

// Variables for VM configuration
var isWindows = (vmConfig.osType == 'Windows')
var isLinux = (vmConfig.osType == 'Linux')

var imageReference = isWindows ? {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2022-datacenter-azure-edition'
  version: 'latest'
} : {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

var networkInterfaceConfigurations = [
  {
    name: '${vmScaleSetName}-nic-config'
    properties: {
      primary: true
      enableAcceleratedNetworking: vmConfig.networkInterface.enableAcceleratedNetworking
      enableIPForwarding: vmConfig.networkInterface.enableIpForwarding
      networkSecurityGroup: (networkSecurityGroupId != null) ? {
        id: networkSecurityGroupId
      } : null
      ipConfigurations: [
        {
          name: '${vmScaleSetName}-ip-config'
          properties: {
            primary: true
            subnet: {
              id: subnetId
            }
            loadBalancerBackendAddressPools: map(loadBalancerBackendAddressPoolIds, poolId => {
              id: poolId
            })
            applicationGatewayBackendAddressPools: map(applicationGatewayBackendAddressPoolIds, poolId => {
              id: poolId
            })
          }
        }
      ]
    }
  }
]

var osProfile = isWindows ? {
  computerNamePrefix: take(vmScaleSetName, 9)
  adminUsername: adminUsername
  adminPassword: adminPassword
  windowsConfiguration: {
    enableAutomaticUpdates: true
    provisionVMAgent: true
    patchSettings: {
      patchMode: 'AutomaticByOS'
      automaticByPlatformSettings: {
        rebootSetting: 'IfRequired'
      }
    }
  }
} : {
  computerNamePrefix: take(vmScaleSetName, 9)
  adminUsername: adminUsername
  linuxConfiguration: {
    disablePasswordAuthentication: true
    ssh: {
      publicKeys: [
        {
          path: '/home/${adminUsername}/.ssh/authorized_keys'
          keyData: sshPublicKey
        }
      ]
    }
    patchSettings: {
      patchMode: 'ImageDefault'
    }
  }
}

var storageProfile = {
  imageReference: imageReference
  osDisk: {
    createOption: 'FromImage'
    caching: 'ReadWrite'
    managedDisk: {
      storageAccountType: vmConfig.osDisk.storageAccountType
    }
    diskSizeGB: vmConfig.osDisk.diskSizeGB
  }
  dataDisks: map((vmConfig.dataDisks ?? []), disk => {
    lun: disk.lun
    createOption: 'Empty'
    caching: 'ReadWrite'
    managedDisk: {
      storageAccountType: disk.storageAccountType
    }
    diskSizeGB: disk.diskSizeGB
  })
}

var extensionProfile = !empty(customScriptExtension) ? {
  extensions: [
    {
      name: 'CustomScriptExtension'
      properties: {
        publisher: isWindows ? 'Microsoft.Compute' : 'Microsoft.Azure.Extensions'
        type: isWindows ? 'CustomScriptExtension' : 'CustomScript'
        typeHandlerVersion: isWindows ? '1.10' : '2.1'
        autoUpgradeMinorVersion: true
        settings: customScriptExtension
      }
    }
  ]
} : null

// VM Scale Set resource
resource vmScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2023-09-01' = {
  name: vmScaleSetName
  location: location
  tags: tags
  zones: availabilityZones
  sku: {
    name: vmConfig.vmSize
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    singlePlacementGroup: singlePlacementGroup
    upgradePolicy: {
      mode: upgradeMode
      rollingUpgradePolicy: (upgradeMode == 'Rolling') ? {
        maxBatchInstancePercent: 20
        maxUnhealthyInstancePercent: 20
        maxUnhealthyUpgradedInstancePercent: 20
        pauseTimeBetweenBatches: 'PT0S'
      } : null
    }
    virtualMachineProfile: {
      osProfile: osProfile
      storageProfile: storageProfile
      networkProfile: {
        networkInterfaceConfigurations: networkInterfaceConfigurations
      }
      extensionProfile: extensionProfile
      diagnosticsProfile: enableBootDiagnostics ? {
        bootDiagnostics: {
          enabled: true
          storageUri: bootDiagnosticsStorageUri
        }
      } : null
    }
    overprovision: overprovision
    doNotRunExtensionsOnOverprovisionedVMs: false
    zoneBalance: true
    platformFaultDomainCount: 1
  }
}

// Autoscale settings (only for Standard SKU load balancers)
resource autoscaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (enableAutoscaling) {
  name: '${vmScaleSetName}-autoscale'
  location: location
  tags: tags
  properties: {
    name: '${vmScaleSetName}-autoscale'
    targetResourceUri: vmScaleSet.id
    enabled: true
    profiles: [
      {
        name: 'Default'
        capacity: {
          minimum: string(minInstanceCount)
          maximum: string(maxInstanceCount)
          default: string(instanceCount)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
              metricResourceUri: vmScaleSet.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 75
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
              metricResourceUri: vmScaleSet.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 25
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
    notifications: []
  }
}

// Outputs
@description('The resource ID of the VM scale set')
output vmScaleSetId string = vmScaleSet.id

@description('The name of the VM scale set')
output vmScaleSetName string = vmScaleSet.name

@description('The autoscale settings resource ID')
output autoscaleSettingsId string = enableAutoscaling ? autoscaleSettings.id : ''

@description('The VM scale set configuration details')
output vmScaleSetConfig object = {
  resourceId: vmScaleSet.id
  name: vmScaleSet.name
  tier: tier
  vmSize: vmConfig.vmSize
  osType: vmConfig.osType
  instanceCount: instanceCount
  availabilityZones: availabilityZones
  autoscalingEnabled: enableAutoscaling
  minInstanceCount: enableAutoscaling ? minInstanceCount : instanceCount
  maxInstanceCount: enableAutoscaling ? maxInstanceCount : instanceCount
}

@description('The network interface configuration name')
output networkInterfaceConfigurationName string = networkInterfaceConfigurations[0].name