/*
.Synopsis
    Bicep template for Virtual Network.
    Template:
      - https://docs.microsoft.com/en-us/azure/templates/Microsoft.Network/virtualNetworks?tabs=bicep#template-format

.NOTES
    Author     : Roman Rabodzei
    Version    : 1.0.240621
*/

/// deployment scope
targetScope = 'resourceGroup'

/// parameters
param location string

param virtualNetworkDeployment bool

param virtualNetworkName string
param virtualNetworkAddressPrefix string = ''

param virtualSubnetNames array
param virtualNetworkSubnetAddressPrefixes array
param networkSecurityGroupNames array

/// monitoring
param logAnalyticsWorkspaceName string = ''
param logAnalyticsWorkspaceResourceGroupName string = ''

/// tags
param tags object = {}

/// resources
resource virtualNetwork_existing_resource 'Microsoft.Network/virtualNetworks@2023-11-01' existing = if (!virtualNetworkDeployment) {
  name: virtualNetworkName
}

resource virtualNetwork_subnet_existing_resource 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = [
  for (virtualSubnetName, i) in virtualSubnetNames: if (!virtualNetworkDeployment) {
    name: toLower(virtualSubnetName)
    parent: virtualNetwork_existing_resource
    properties: {
      addressPrefix: virtualNetworkSubnetAddressPrefixes[i]
      networkSecurityGroup: {
        id: resourceId('Microsoft.Network/networkSecurityGroups', toLower(networkSecurityGroupNames[i]))
      }
    }
    dependsOn: [
      networkSecurityGroup_resource
    ]
  }
]

resource virtualNetwork_new_resource 'Microsoft.Network/virtualNetworks@2023-11-01' = if (virtualNetworkDeployment) {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
  }
}

resource virtualNetwork_subnet_new_resource 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = [
  for (virtualSubnetName, i) in virtualSubnetNames: if (virtualNetworkDeployment) {
    name: toLower(virtualSubnetName)
    parent: virtualNetwork_new_resource
    properties: {
      addressPrefix: virtualNetworkSubnetAddressPrefixes[i]
      networkSecurityGroup: {
        id: resourceId('Microsoft.Network/networkSecurityGroups', toLower(networkSecurityGroupNames[i]))
      }
    }
    dependsOn: [
      networkSecurityGroup_resource
    ]
  }
]

var networkSecurityGroups = [
  'containerApps'
  'privateEndpoints'
]

var securityRules = {
  containerApps: [
    {
      name: 'AllowAnyHTTPSInbound'
      properties: {
        protocol: 'TCP'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
        access: 'Allow'
        priority: 100
        direction: 'Inbound'
        sourcePortRanges: []
        destinationPortRanges: []
        sourceAddressPrefixes: []
        destinationAddressPrefixes: []
      }
    }
  ]
  privateEndpoints: []
}

resource networkSecurityGroup_resource 'Microsoft.Network/networkSecurityGroups@2023-11-01' = [
  for (networkSecurityGroup, i) in networkSecurityGroups: {
    name: toLower(networkSecurityGroupNames[i])
    location: location
    tags: tags
    properties: {
      securityRules: securityRules[networkSecurityGroup]
    }
  }
]

resource logAnalytics_resource 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = if (!empty(logAnalyticsWorkspaceName) && !empty(logAnalyticsWorkspaceResourceGroupName)) {
  scope: resourceGroup(logAnalyticsWorkspaceResourceGroupName)
  name: logAnalyticsWorkspaceName
}

resource send_data_to_logAnalyticsWorkspace 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceName) && !empty(logAnalyticsWorkspaceResourceGroupName)) {
  scope: virtualNetwork_new_resource
  name: toLower('send-data-to-${logAnalyticsWorkspaceName}')
  properties: {
    workspaceId: logAnalytics_resource.id
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

/// output
output virtualNetworkId string = virtualNetworkDeployment
  ? virtualNetwork_existing_resource.id
  : virtualNetwork_new_resource.id