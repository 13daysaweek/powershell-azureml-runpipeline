# Put some title here
This repo contains a PowerShell script that will start an AzureML pipeline and monitor the run's status until the run reaches a final status, either `Completed` or `Failed`.  The script will then return an exit code, either `0` for success or `1 for failed`

## Usage
```powershell
$clientId = 'your service principal client id'
$clientSecret = 'your service principal client secret'
$tenantId = 'your Azure AD tenant id'
$pipelineId = 'id (guid) of pipeline you want to run'
$experimentName = 'name of AzureML experiement'
$workspaceName = 'name of your AzureML workspace'
$resourceGroupName = 'name of resource group that contains your AML workspace'
$secondsBetweenStatusCheck = 60 # number of seconds to sleep before checking the run status again

.\run-pipelin1.ps1 -ClientId $clientId -ClientSecret $clientSecret -TenantId $tenantId -PipelineId $pipelineId -ExperimentName $experimentName -WorkspaceName $workspaceName -ResourceGroupName $resourceGroupName -SecondsBetweenStatusCheck $secondsBetweenStatusCheck
```
