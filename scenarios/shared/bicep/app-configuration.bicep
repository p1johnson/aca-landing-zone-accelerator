@description('Required. Name of your Azure App Configuration store.')
@minLength(5)
@maxLength(50)
param name string

@description('Required. Location for all resources.')
param location string

@description('Optional. Enables system assigned managed identity on the resource.')
param systemAssignedIdentity bool = false

@description('Optional. The ID(s) to assign to the resource.')
param userAssignedIdentities object = {}

@description('Optional. Tags of the resource.')
param tags object = {}

@description('Optional. Tier of your Azure container registry.')
@allowed([
  'Free'
  'Standard'
])
param aacSku string = 'Standard'

@description('Optional. Disables all authentication methods other than AAD authentication.')
param disableLocalAuth bool = true

@description('Optional. Property specifying whether protection against purge is enabled for this configuration store. Defaults to true unless sku is set to Free, since purge protection is not available in Free tier.')
param enablePurgeProtection bool = true

@description('Optional. Whether or not public network access is allowed for this resource. For security reasons it should be disabled. If not specified, it will be disabled by default unless sku is set to Free.')
@allowed([
  ''
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string

@description('Optional. The amount of time in days that the configuration store will be retained when it is soft deleted.')
@minValue(1)
@maxValue(7)
param softDeleteRetentionInDays int = 1

@description('Optional. Key values to create')
param keyValues array?

var identityType = systemAssignedIdentity ? (!empty(userAssignedIdentities) ? 'SystemAssigned,UserAssigned' : 'SystemAssigned') : (!empty(userAssignedIdentities) ? 'UserAssigned' : 'None')

var identity = identityType != 'None' ? {
  type: identityType
  userAssignedIdentities: !empty(userAssignedIdentities) ? userAssignedIdentities : null
} : null


resource store 'Microsoft.AppConfiguration/configurationStores@2024-05-01' = {
  name: name
  location: location
  identity: identity
  tags: tags
  sku: {
    name: aacSku
  }
  properties: {
    disableLocalAuth: disableLocalAuth
    enablePurgeProtection: aacSku == 'Free' ? false : enablePurgeProtection
    publicNetworkAccess: !empty(publicNetworkAccess)
      ? any(publicNetworkAccess)
      : (aacSku == 'Free' ? 'Enabled' : 'Disabled')
    softDeleteRetentionInDays: aacSku == 'Free' ? 0 : softDeleteRetentionInDays
    dataPlaneProxy: {
      authenticationMode: disableLocalAuth ? 'Pass-through' : 'Local'
    }
  }
}

module storeKeyValues 'key-values.bicep' = [
  for (keyValue, index) in (keyValues ?? []): {
    name: '${uniqueString(deployment().name, location)}-AppConfig-KeyValues-${index}'
    params: {
      appConfigurationName: store.name
      name: keyValue.name
      value: keyValue.value
      contentType: keyValue.?contentType
      tags: keyValue.?tags ?? tags
    }
  }
]

@description('The Name of the Azure App Configuration store.')
output name string = store.name

@description('The name of the Azure App Configuration store resource group.')
output resourceGroupName string = resourceGroup().name

@description('The resource ID of the Azure App Configuration store.')
output resourceId string = store.id

@description('The DNS endpoint where the configuration store API will be available.')
output endpoint string = store.properties.endpoint

@description('The principal ID of the system assigned identity.')
output systemAssignedPrincipalId string = systemAssignedIdentity && contains(store.identity, 'principalId') ? store.identity.principalId : ''

@description('The location the resource was deployed into.')
output location string = store.location
