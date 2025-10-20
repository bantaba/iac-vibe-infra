// Application Gateway with Web Application Firewall module
// This module creates an Application Gateway with WAF capabilities, SSL termination, and backend pool management
// Supports multi-tier application architecture with health probes and load balancing

targetScope = 'resourceGroup'

// Import shared modules
import { TagConfiguration } from '../shared/parameter-schemas.bicep'

@description('The name of the Application Gateway')
param applicationGatewayName string

@description('The subnet ID for the Application Gateway')
param subnetId string

@description('The SKU of the Application Gateway')
@allowed(['Standard_v2', 'WAF_v2'])
param sku string = 'WAF_v2'

@description('The capacity (instance count) of the Application Gateway')
@minValue(1)
@maxValue(125)
param capacity int = 2

@description('Enable autoscaling for the Application Gateway')
param enableAutoscaling bool = true

@description('Minimum autoscale instance count')
@minValue(1)
@maxValue(125)
param minCapacity int = 1

@description('Maximum autoscale instance count')
@minValue(1)
@maxValue(125)
param maxCapacity int = 10

@description('Public IP address resource ID for the Application Gateway')
param publicIpAddressId string

@description('Key Vault resource ID for SSL certificates')
param keyVaultId string?

@description('SSL certificate name in Key Vault')
param sslCertificateName string?

@description('Managed identity resource ID for Key Vault access')
param managedIdentityId string?

@description('Backend pool configurations')
param backendPools array = [
  {
    name: 'web-tier-pool'
    backendAddresses: []
  }
]

@description('Backend HTTP settings configurations')
param backendHttpSettings array = [
  {
    name: 'web-tier-http-settings'
    port: 80
    protocol: 'Http'
    cookieBasedAffinity: 'Disabled'
    requestTimeout: 30
    probeName: 'web-tier-health-probe'
  }
  {
    name: 'web-tier-https-settings'
    port: 443
    protocol: 'Https'
    cookieBasedAffinity: 'Disabled'
    requestTimeout: 30
    probeName: 'web-tier-https-health-probe'
  }
]

@description('Health probe configurations')
param healthProbes array = [
  {
    name: 'web-tier-health-probe'
    protocol: 'Http'
    host: ''
    path: '/health'
    interval: 30
    timeout: 30
    unhealthyThreshold: 3
    port: 80
  }
  {
    name: 'web-tier-https-health-probe'
    protocol: 'Https'
    host: ''
    path: '/health'
    interval: 30
    timeout: 30
    unhealthyThreshold: 3
    port: 443
  }
]

@description('HTTP listeners configurations')
param httpListeners array = [
  {
    name: 'http-listener'
    frontendIpConfiguration: 'public-frontend-ip'
    frontendPort: 'port-80'
    protocol: 'Http'
  }
  {
    name: 'https-listener'
    frontendIpConfiguration: 'public-frontend-ip'
    frontendPort: 'port-443'
    protocol: 'Https'
    sslCertificate: 'ssl-certificate'
  }
]

@description('Request routing rules configurations')
param requestRoutingRules array = [
  {
    name: 'http-routing-rule'
    ruleType: 'Basic'
    priority: 100
    httpListener: 'http-listener'
    backendAddressPool: 'web-tier-pool'
    backendHttpSettings: 'web-tier-http-settings'
  }
  {
    name: 'https-routing-rule'
    ruleType: 'Basic'
    priority: 200
    httpListener: 'https-listener'
    backendAddressPool: 'web-tier-pool'
    backendHttpSettings: 'web-tier-https-settings'
  }
]

@description('WAF configuration')
param wafConfiguration object = {
  enabled: true
  firewallMode: 'Prevention'
  ruleSetType: 'OWASP'
  ruleSetVersion: '3.2'
  disabledRuleGroups: []
  requestBodyCheck: true
  maxRequestBodySizeInKb: 128
  fileUploadLimitInMb: 100
}

@description('Custom WAF rules')
param customWafRules array = []

@description('Tags to apply to all resources')
param tags TagConfiguration

@description('Location for the Application Gateway')
param location string = resourceGroup().location

@description('Enable HTTP/2 support')
param enableHttp2 bool = true

@description('Enable WAF')
param enableWaf bool = (sku == 'WAF_v2')

// Variables for resource configuration
var frontendIpConfigurations = [
  {
    name: 'public-frontend-ip'
    properties: {
      publicIPAddress: {
        id: publicIpAddressId
      }
    }
  }
]

var frontendPorts = [
  {
    name: 'port-80'
    properties: {
      port: 80
    }
  }
  {
    name: 'port-443'
    properties: {
      port: 443
    }
  }
]

var sslCertificates = (keyVaultId != null && sslCertificateName != null && managedIdentityId != null) ? [
  {
    name: 'ssl-certificate'
    properties: {
      keyVaultSecretId: '${keyVaultId}/secrets/${sslCertificateName}'
    }
  }
] : []

var gatewayIpConfigurations = [
  {
    name: 'gateway-ip-configuration'
    properties: {
      subnet: {
        id: subnetId
      }
    }
  }
]

var backendAddressPools = [for pool in backendPools: {
  name: pool.name
  properties: {
    backendAddresses: pool.backendAddresses
  }
}]

var backendHttpSettingsCollection = [for setting in backendHttpSettings: {
  name: setting.name
  properties: {
    port: setting.port
    protocol: setting.protocol
    cookieBasedAffinity: setting.cookieBasedAffinity
    requestTimeout: setting.requestTimeout
    probe: contains(setting, 'probeName') ? {
      id: resourceId('Microsoft.Network/applicationGateways/probes', applicationGatewayName, setting.probeName)
    } : null
    pickHostNameFromBackendAddress: false
    affinityCookieName: ''
    trustedRootCertificates: []
    connectionDraining: {
      enabled: false
      drainTimeoutInSec: 1
    }
  }
}]

var probes = [for probe in healthProbes: {
  name: probe.name
  properties: {
    protocol: probe.protocol
    host: empty(probe.host) ? '127.0.0.1' : probe.host
    path: probe.path
    interval: probe.interval
    timeout: probe.timeout
    unhealthyThreshold: probe.unhealthyThreshold
    port: probe.port
    pickHostNameFromBackendHttpSettings: empty(probe.host)
    minServers: 0
    match: {
      statusCodes: ['200-399']
    }
  }
}]

var httpListenersCollection = [for listener in httpListeners: {
  name: listener.name
  properties: {
    frontendIPConfiguration: {
      id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, listener.frontendIpConfiguration)
    }
    frontendPort: {
      id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, listener.frontendPort)
    }
    protocol: listener.protocol
    sslCertificate: (listener.protocol == 'Https' && contains(listener, 'sslCertificate')) ? {
      id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', applicationGatewayName, listener.sslCertificate)
    } : null
    requireServerNameIndication: (listener.protocol == 'Https')
  }
}]

var requestRoutingRulesCollection = [for rule in requestRoutingRules: {
  name: rule.name
  properties: {
    ruleType: rule.ruleType
    priority: rule.priority
    httpListener: {
      id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, rule.httpListener)
    }
    backendAddressPool: {
      id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, rule.backendAddressPool)
    }
    backendHttpSettings: {
      id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, rule.backendHttpSettings)
    }
  }
}]

// Application Gateway resource
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: applicationGatewayName
  location: location
  tags: tags
  identity: (managedIdentityId != null) ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  } : null
  properties: {
    sku: {
      name: sku
      tier: sku
      capacity: enableAutoscaling ? null : capacity
    }
    autoscaleConfiguration: enableAutoscaling ? {
      minCapacity: minCapacity
      maxCapacity: maxCapacity
    } : null
    gatewayIPConfigurations: gatewayIpConfigurations
    frontendIPConfigurations: frontendIpConfigurations
    frontendPorts: frontendPorts
    sslCertificates: sslCertificates
    backendAddressPools: backendAddressPools
    backendHttpSettingsCollection: backendHttpSettingsCollection
    httpListeners: httpListenersCollection
    requestRoutingRules: requestRoutingRulesCollection
    probes: probes
    webApplicationFirewallConfiguration: enableWaf ? {
      enabled: wafConfiguration.enabled
      firewallMode: wafConfiguration.firewallMode
      ruleSetType: wafConfiguration.ruleSetType
      ruleSetVersion: wafConfiguration.ruleSetVersion
      disabledRuleGroups: wafConfiguration.disabledRuleGroups
      requestBodyCheck: wafConfiguration.requestBodyCheck
      maxRequestBodySizeInKb: wafConfiguration.maxRequestBodySizeInKb
      fileUploadLimitInMb: wafConfiguration.fileUploadLimitInMb
    } : null
    firewallPolicy: !empty(customWafRules) ? {
      id: wafPolicy.id
    } : null
    enableHttp2: enableHttp2
    forceFirewallPolicyAssociation: !empty(customWafRules)
  }
}

// WAF Policy for custom rules (only created if custom rules are provided)
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-09-01' = if (!empty(customWafRules)) {
  name: '${applicationGatewayName}-waf-policy'
  location: location
  tags: tags
  properties: {
    policySettings: {
      requestBodyCheck: wafConfiguration.requestBodyCheck
      maxRequestBodySizeInKb: wafConfiguration.maxRequestBodySizeInKb
      fileUploadLimitInMb: wafConfiguration.fileUploadLimitInMb
      state: 'Enabled'
      mode: wafConfiguration.firewallMode
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: wafConfiguration.ruleSetType
          ruleSetVersion: wafConfiguration.ruleSetVersion
          ruleGroupOverrides: wafConfiguration.disabledRuleGroups
        }
      ]
    }
    customRules: customWafRules
  }
}

// Outputs
@description('The resource ID of the Application Gateway')
output applicationGatewayId string = applicationGateway.id

@description('The name of the Application Gateway')
output applicationGatewayName string = applicationGateway.name

@description('The public IP address of the Application Gateway')
output publicIpAddress string = reference(publicIpAddressId, '2023-09-01').ipAddress

@description('The backend address pool resource IDs')
output backendAddressPoolIds object = {
  for pool in backendPools: pool.name => resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, pool.name)
}

@description('The frontend IP configuration resource ID')
output frontendIpConfigurationId string = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'public-frontend-ip')

@description('The WAF policy resource ID (if created)')
output wafPolicyId string = !empty(customWafRules) ? wafPolicy.id : ''

@description('The Application Gateway configuration details')
output applicationGatewayConfig object = {
  resourceId: applicationGateway.id
  name: applicationGateway.name
  sku: sku
  capacity: enableAutoscaling ? 'Autoscaling' : string(capacity)
  wafEnabled: enableWaf
  http2Enabled: enableHttp2
  backendPools: [for pool in backendPools: pool.name]
  listeners: [for listener in httpListeners: listener.name]
}