// Network Security Groups module
// This module implements NSG rules following principle of least privilege
// Configures tier-specific security rules for web, business, and data layers

targetScope = 'resourceGroup'

// Import shared modules
import { TagConfiguration, NsgRuleConfig } from '../shared/parameter-schemas.bicep'

@description('The prefix for NSG names')
param nsgNamePrefix string

@description('Tags to apply to all resources')
param tags TagConfiguration

@description('Location for the NSGs')
param location string = resourceGroup().location

@description('Virtual network address space for internal traffic rules')
param vnetAddressSpace string = '10.0.0.0/16'

@description('Application Gateway subnet address prefix')
param applicationGatewaySubnet string = '10.0.1.0/24'

@description('Management subnet address prefix')
param managementSubnet string = '10.0.2.0/24'

@description('Web tier subnet address prefix')
param webTierSubnet string = '10.0.3.0/24'

@description('Business tier subnet address prefix')
param businessTierSubnet string = '10.0.4.0/24'

@description('Data tier subnet address prefix')
param dataTierSubnet string = '10.0.5.0/24'

@description('Active Directory subnet address prefix')
param activeDirectorySubnet string = '10.0.6.0/24'

// Application Gateway NSG
resource applicationGatewayNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${nsgNamePrefix}-agw-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-Internet-HTTP-HTTPS'
        properties: {
          description: 'Allow HTTP and HTTPS traffic from internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: applicationGatewaySubnet
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-GatewayManager'
        properties: {
          description: 'Allow Azure Gateway Manager'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-AzureLoadBalancer'
        properties: {
          description: 'Allow Azure Load Balancer'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-WebTier-Outbound'
        properties: {
          description: 'Allow traffic to web tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: applicationGatewaySubnet
          destinationAddressPrefix: webTierSubnet
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Management NSG
resource managementNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${nsgNamePrefix}-mgmt-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-From-Management'
        properties: {
          description: 'Allow RDP from management subnet only'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: managementSubnet
          destinationAddressPrefix: managementSubnet
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-SSH-From-Management'
        properties: {
          description: 'Allow SSH from management subnet only'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: managementSubnet
          destinationAddressPrefix: managementSubnet
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-HTTPS-To-All-Tiers'
        properties: {
          description: 'Allow HTTPS management traffic to all tiers'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: managementSubnet
          destinationAddressPrefix: vnetAddressSpace
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Web Tier NSG
resource webTierNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${nsgNamePrefix}-web-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-ApplicationGateway'
        properties: {
          description: 'Allow traffic from Application Gateway'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: applicationGatewaySubnet
          destinationAddressPrefix: webTierSubnet
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Management-RDP'
        properties: {
          description: 'Allow RDP from management subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: managementSubnet
          destinationAddressPrefix: webTierSubnet
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Management-SSH'
        properties: {
          description: 'Allow SSH from management subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: managementSubnet
          destinationAddressPrefix: webTierSubnet
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-BusinessTier-Outbound'
        properties: {
          description: 'Allow traffic to business tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443', '8080', '8443']
          sourceAddressPrefix: webTierSubnet
          destinationAddressPrefix: businessTierSubnet
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Business Tier NSG
resource businessTierNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${nsgNamePrefix}-biz-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-WebTier'
        properties: {
          description: 'Allow traffic from web tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443', '8080', '8443']
          sourceAddressPrefix: webTierSubnet
          destinationAddressPrefix: businessTierSubnet
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Management-RDP'
        properties: {
          description: 'Allow RDP from management subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: managementSubnet
          destinationAddressPrefix: businessTierSubnet
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Management-SSH'
        properties: {
          description: 'Allow SSH from management subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: managementSubnet
          destinationAddressPrefix: businessTierSubnet
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-DataTier-Outbound'
        properties: {
          description: 'Allow traffic to data tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['1433', '3306', '5432']
          sourceAddressPrefix: businessTierSubnet
          destinationAddressPrefix: dataTierSubnet
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Data Tier NSG
resource dataTierNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${nsgNamePrefix}-data-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-BusinessTier-SQL'
        properties: {
          description: 'Allow SQL traffic from business tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '1433'
          sourceAddressPrefix: businessTierSubnet
          destinationAddressPrefix: dataTierSubnet
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-BusinessTier-MySQL'
        properties: {
          description: 'Allow MySQL traffic from business tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3306'
          sourceAddressPrefix: businessTierSubnet
          destinationAddressPrefix: dataTierSubnet
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-BusinessTier-PostgreSQL'
        properties: {
          description: 'Allow PostgreSQL traffic from business tier'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5432'
          sourceAddressPrefix: businessTierSubnet
          destinationAddressPrefix: dataTierSubnet
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Management-RDP'
        properties: {
          description: 'Allow RDP from management subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: managementSubnet
          destinationAddressPrefix: dataTierSubnet
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Management-SSH'
        properties: {
          description: 'Allow SSH from management subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: managementSubnet
          destinationAddressPrefix: dataTierSubnet
          access: 'Allow'
          priority: 140
          direction: 'Inbound'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
      {
        name: 'Deny-Internet-Outbound'
        properties: {
          description: 'Deny internet access from data tier'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: dataTierSubnet
          destinationAddressPrefix: 'Internet'
          access: 'Deny'
          priority: 4000
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Active Directory NSG
resource activeDirectoryNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${nsgNamePrefix}-ad-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-LDAP'
        properties: {
          description: 'Allow LDAP traffic from VNet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '389'
          sourceAddressPrefix: vnetAddressSpace
          destinationAddressPrefix: activeDirectorySubnet
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-LDAPS'
        properties: {
          description: 'Allow LDAPS traffic from VNet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '636'
          sourceAddressPrefix: vnetAddressSpace
          destinationAddressPrefix: activeDirectorySubnet
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Kerberos'
        properties: {
          description: 'Allow Kerberos traffic from VNet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '88'
          sourceAddressPrefix: vnetAddressSpace
          destinationAddressPrefix: activeDirectorySubnet
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-DNS'
        properties: {
          description: 'Allow DNS traffic from VNet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: vnetAddressSpace
          destinationAddressPrefix: activeDirectorySubnet
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-Management-RDP'
        properties: {
          description: 'Allow RDP from management subnet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: managementSubnet
          destinationAddressPrefix: activeDirectorySubnet
          access: 'Allow'
          priority: 140
          direction: 'Inbound'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Outputs
@description('The resource IDs of all NSGs')
output nsgIds object = {
  applicationGateway: applicationGatewayNsg.id
  management: managementNsg.id
  webTier: webTierNsg.id
  businessTier: businessTierNsg.id
  dataTier: dataTierNsg.id
  activeDirectory: activeDirectoryNsg.id
}

@description('The names of all NSGs')
output nsgNames object = {
  applicationGateway: applicationGatewayNsg.name
  management: managementNsg.name
  webTier: webTierNsg.name
  businessTier: businessTierNsg.name
  dataTier: dataTierNsg.name
  activeDirectory: activeDirectoryNsg.name
}