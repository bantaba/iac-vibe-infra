// Public IP Address module
// This module creates public IP addresses for Application Gateway and other public-facing resources

targetScope = 'resourceGroup'

// Import shared modules
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

@description('The name of the public IP address')
param publicIpName string

@description('The SKU of the public IP address')
@allowed(['Basic', 'Standard'])
param sku string = 'Standard'

@description('The allocation method for the public IP address')
@allowed(['Static', 'Dynamic'])
param allocationMethod string = 'Static'

@description('The IP version for the public IP address')
@allowed(['IPv4', 'IPv6'])
param ipVersion string = 'IPv4'

@description('The idle timeout in minutes')
@minValue(4)
@maxValue(30)
param idleTimeoutInMinutes int = 4

@description('The domain name label for the public IP address')
param domainNameLabel string?

@description('Availability zones for the public IP address (Standard SKU only)')
param zones array = ['1', '2', '3']

@description('Tags to apply to the public IP address')
param tags TagConfiguration

@description('Location for the public IP address')
param location string = resourceGroup().location

// Public IP Address resource
resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: sku
    tier: 'Regional'
  }
  zones: (sku == 'Standard') ? zones : null
  properties: {
    publicIPAllocationMethod: allocationMethod
    publicIPAddressVersion: ipVersion
    idleTimeoutInMinutes: idleTimeoutInMinutes
    dnsSettings: domainNameLabel != null ? {
      domainNameLabel: domainNameLabel
    } : null
  }
}

// Outputs
@description('The resource ID of the public IP address')
output publicIpAddressId string = publicIpAddress.id

@description('The name of the public IP address')
output publicIpAddressName string = publicIpAddress.name

@description('The IP address value')
output ipAddress string = publicIpAddress.properties.ipAddress

@description('The FQDN of the public IP address')
output fqdn string = domainNameLabel != null ? publicIpAddress.properties.dnsSettings.fqdn : ''

@description('The public IP address configuration details')
output publicIpConfig object = {
  resourceId: publicIpAddress.id
  name: publicIpAddress.name
  ipAddress: publicIpAddress.properties.ipAddress
  allocationMethod: allocationMethod
  sku: sku
  zones: (sku == 'Standard') ? zones : []
}