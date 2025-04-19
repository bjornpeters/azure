@description('Array of managed identities to deploy')
param managedIdentities managedIdentityType[] = [
  {
    name: 'id1'
    federatedIdentityCredentials: [
      {
        name: 'cred1'
        audiences: [
          'api://AzureADTokenExchange'
        ]
        issuer: 'iss1'
        subject: 'sub1'
      }
    ]
    audiences: [
      'aud1'
      'aud2'
    ]
    issuer: 'iss1'
    subject: 'sub1'
  }
  {
    name: 'id2'
    audiences: [
      'aud3'
      'aud4'
    ]
    issuer: 'iss2'
    subject: 'sub2'
  }
]

module userAssignedIdentities 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = [for managedIdentity in managedIdentities: {
  name: managedIdentity.name
  params: {
    name: managedIdentity.name
    location: resourceGroup().location
    federatedIdentityCredentials: managedIdentity.federatedIdentityCredentials
    enableTelemetry: false
  }
}]

@description('Type for federated identity credential')
type federatedIdentityCredentialType = {
  @description('The name of the federated identity credential')
  name: string

  @description('The audiences for the federated identity credential')
  audiences: array

  @description('The issuer for the federated identity credential')
  issuer: string

  @description('The subject for the federated identity credential')
  subject: string
}

@description('Type for managed identity configuration')
type managedIdentityType = {
  @description('The name of the managed identity')
  name: string

  @description('Optional. The federated identity credentials for the managed identity')
  federatedIdentityCredentials: federatedIdentityCredentialType[]

  @description('The audiences for the managed identity')
  audiences: array

  @description('The issuer for the managed identity')
  issuer: string

  @description('The subject for the managed identity')
  subject: string
}
