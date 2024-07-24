// ================ //
// Parameters       //
// ================ //
@description('Required. Set lock level.')
@allowed([
  'CanNotDelete'
  'ReadOnly'
])
param level string

@description('Optional. The description attached to the lock.')
param notes string = level == 'CanNotDelete' ? 'Cannot delete resource or child resources.' : 'Cannot modify the resource or child resources.'

@description('Required. The scope where to deploy the lock into')
@allowed([
  'resourceGroup'
  'resource'
])
param scope string


@description('Required. The asset name this lock applies to.')
param assetName string



// =========== //
// Deployments //
// =========== //
module lock 'resourceGroup/deploy.bicep' = if (scope  == 'resourceGroup') {
  name: '${uniqueString(deployment().name)}-lockRG' 
  scope: scope
  params: {
    name: '${assetName}-${level}-lock'
    level: level
    notes: notes
  }
}



// =========== //
//   Outputs   //
// =========== //
@description('The name of the lock.')
output name string = lock.outputs.name

@description('The resource ID of the lock.')
output resourceId string = lock.outputs.resourceId

@sys.description('The scope this lock applies to.')
output scope string = lock.outputs.scope
