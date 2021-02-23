# Running Azure Machine Learning pipelines with PowerShell
This repo contains a PowerShell script that will start an Azure Machine Learning pipeline and monitor the run's status until the run reaches a final status, either `Completed` or `Failed`.  The script will then return an exit code, either `0` for success or `1` for failed.  The pipeline run is started and status is monitored using the Azure ML REST APIs.  The previous version of this script used <a href="https://docs.microsoft.com/en-us/azure/machine-learning/reference-azure-machine-learning-cli" target="_blank">az cli + Azure Machine Learning extension</a> instead.  The az cli version can still be found in the `azureclirunpipeline` branch.

## Usage
```powershell
$clientId = 'your service principal client id'
$clientSecret = 'your service principal client secret'
$tenantId = 'your Azure AD tenant id'
$pipelineId = 'id (guid) of pipeline you want to run'
$experimentName = 'name of AML experiement'
$workspaceName = 'name of your AML workspace'
$resourceGroupName = 'name of resource group that contains your AML workspace'
$subscriptionId = 'id (guid) of Azure subscription that contains your AML workspace'
$location = 'region where your AML workspace is located'
$secondsBetweenStatusCheck = 60 # number of seconds to sleep before checking the run status again

.\run-pipelin1.ps1 -ClientId $clientId -ClientSecret $clientSecret -TenantId $tenantId -PipelineId $pipelineId -ExperimentName $experimentName -WorkspaceName $workspaceName -ResourceGroupName $resourceGroupName -SubscriptionId $subscriptionId -Location $location -SecondsBetweenStatusCheck $secondsBetweenStatusCheck
```
