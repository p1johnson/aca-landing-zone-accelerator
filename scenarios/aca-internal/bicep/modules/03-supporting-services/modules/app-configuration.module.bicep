targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The name of the app configuration store.')
param appConfigurationStoreName string

@description('Optional. The tags to be assigned to the created resources.')
param tags object = {}

@description('The resource ID of the Hub Virtual Network.')
param hubVNetId string

@description(' Name of the hub vnet')
param hubVNetName string 

@description('The resource ID of the VNet to which the private endpoint will be connected.')
param spokeVNetId string

@description('The name of the subnet in the VNet to which the private endpoint will be connected.')
param spokePrivateEndpointSubnetName string

@description('The name of the private endpoint to be created for Azure App Configuration.')
param appConfigurationStorePrivateEndpointName string

@description('The name of the user assigned identity to be created to access Azure App Configuration.')
param appConfigurationStoreUserAssignedIdentityName string

// ------------------
// VARIABLES
// ------------------

var privateDnsZoneNames = 'privatelink.azconfig.io'
var appConfigurationResourceName = 'configurationStores'

var spokeVNetIdTokens = split(spokeVNetId, '/')
var spokeSubscriptionId = spokeVNetIdTokens[2]
var spokeResourceGroupName = spokeVNetIdTokens[4]
var spokeVNetName = spokeVNetIdTokens[8]

var appConfigurationDataReaderRoleGuid = '516239f1-63e1-4d78-a4de-a74fb236a071'

// Only include hubvnet to the mix if a valid hubvnet id is provided
var spokeVNetLinks = concat(
  [
    {
      vnetName: spokeVNetName
      vnetId: vnetSpoke.id
      registrationEnabled: false
    }
  ],
  !empty(hubVNetName) ? [
    {
      vnetName: hubVNetName
      vnetId: hubVNetId
      registrationEnabled: false
    }
  ] : []
)

@description('Optional. Key values to create')
param keyValues array?

// ------------------
// RESOURCES
// ------------------

resource vnetSpoke 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: resourceGroup(spokeSubscriptionId, spokeResourceGroupName)
  name: spokeVNetName
}

resource spokePrivateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnetSpoke
  name: spokePrivateEndpointSubnetName
}

module appConfiguration '../../../../../shared/bicep/app-configuration.bicep' = {
  name: take('appConfigurationNameDeployment-${deployment().name}', 64)
  params: {
    location: location
    tags: tags
    name: appConfigurationStoreName
    aacSku: 'Standard'
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
    enablePurgeProtection: false
    softDeleteRetentionInDays: 1
    keyValues: keyValues
  }
}

module appConfigurationNetwork '../../../../../shared/bicep/network/private-networking.bicep' = {
  name:take('appConfigurationNetworkDeployment-${deployment().name}', 64)
  params: {
    location: location
    azServicePrivateDnsZoneName: privateDnsZoneNames
    azServiceId: appConfiguration.outputs.resourceId
    privateEndpointName: appConfigurationStorePrivateEndpointName
    privateEndpointSubResourceName: appConfigurationResourceName
    virtualNetworkLinks: spokeVNetLinks
    subnetId: spokePrivateEndpointSubnet.id
    vnetHubResourceId: hubVNetId
  }
}

resource appConfigurationStoreUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: appConfigurationStoreUserAssignedIdentityName
  location: location
  tags: tags
}


module appConfigurationStoreRoleAssignment '../../../../../shared/bicep/role-assignments/role-assignment.bicep' = {
  name: take('appConfigurationStoreRoleAssignmentDeployment-${deployment().name}', 64)
  params: {
    name: 'ra-appConfigurationStoreRoleAssignment'
    principalId: appConfigurationStoreUserAssignedIdentity.properties.principalId
    resourceId: appConfiguration.outputs.resourceId
    roleDefinitionId: appConfigurationDataReaderRoleGuid
  }
}

// ------------------
// OUTPUTS
// ------------------

@description('The resource ID of the app configuration store.')
output appConfigurationStoreId string = appConfiguration.outputs.resourceId

@description('The name of the app configuration store.')
output appConfigurationStoreName string = appConfiguration.outputs.name

@description('The resource ID of the user assigned managed identity for the app configuration store data reader.')
output appConfigurationStoreUserAssignedIdentityId string = appConfigurationStoreUserAssignedIdentity.id

@description('The client id of the user assigned managed identity for the app configuration store data reader')
output appConfigurationStoreUserAssignedIdentityClientId string = appConfigurationStoreUserAssignedIdentity.properties.clientId

@description('The DNS endpoint where the configuration store API will be available.')
output appConfigurationStoreEndpoint string = appConfiguration.outputs.endpoint
