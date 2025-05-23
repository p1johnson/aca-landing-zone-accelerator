targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created. This needs to be the same region as the Azure Container Apps instances.')
param location string = resourceGroup().location

@description('Optional. The tags to be assigned to the created resources.')
param tags object = {}

@description('Optional. The name of the Container App. If set, it overrides the name generated by the template.')
@minLength(2)
@maxLength(32)
param helloWorldContainerAppName string = 'ca-simple-hello'

@description('The resource ID of the existing user-assigned managed identity to be assigned to the Container App to be able to pull images from the container registry.')
param containerRegistryUserAssignedIdentityId string

@description('The resource ID of the existing Container Apps environment in which the Container App will be deployed.')
param containerAppsEnvironmentId string

@description('Optional. The address of the registry login server for the container app. If set, it overrides the Microsoft Container Registry.')
param registryLoginServer string = 'mcr.microsoft.com'

// ------------------
// RESOURCES
// ------------------

@description('The "Hello World" Container App.')
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: helloWorldContainerAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerRegistryUserAssignedIdentityId}': {}
    }
  }
  properties: {
    configuration: {
      activeRevisionsMode: 'single'
      ingress: {
        allowInsecure: false
        external: true
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          identity: containerRegistryUserAssignedIdentityId
          server: registryLoginServer
        }
      ]
      secrets: []
    }
    environmentId: containerAppsEnvironmentId
    workloadProfileName: 'Consumption'
    template: {
      containers: [
        {
          name: 'simple-hello'
          // Production readiness change
          // All workloads should be pulled from your private container registry and not public registries.
          image: '${registryLoginServer}/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
      volumes: []
    }
  }
}

// ------------------
// OUTPUTS
// ------------------

@description('The FQDN of the "Hello World" Container App.')
output helloWorldAppFqdn string = containerApp.properties.configuration.ingress.fqdn
