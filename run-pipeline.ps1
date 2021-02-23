[cmdletbinding()]
param(
    [parameter(Mandatory="true")]
    [string] $ClientId,
    [parameter(Mandatory="true")]
    [string] $ClientSecret,
    [parameter(Mandatory="true")]
    [string] $TenantId,
    [parameter(Mandatory="true")]
    [string] $PipelineId,
    [parameter(Mandatory="true")]
    [string] $ExperimentName,
    [parameter(Mandatory="true")]
    [string] $WorkspaceName,
    [parameter(Mandatory="true")]
    [string] $ResourceGroupName,
    [parameter(Mandatory="true")]
    [string] $SubscriptionId,
    [parameter(Mandatory="true")]
    [string] $Location,
    [parameter(Mandatory="true")]
    [int] $SecondsBetweenStatusCheck = 60
)

function Start-Pipeline {
    param($PipelineId,
    $WorkspaceName,
    $ResourceGroupName,
    $Location,
    $ExperimentName,
    $SubscriptionId,
    $AccessToken)

    $startPipelineUri = "https://$Location.api.azureml.ms/pipelines/v1.0/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.MachineLearningServices/workspaces/$WorkspaceName/PipelineRuns/PipelineSubmit/$PipelineId"
    $headers = @{Authorization="Bearer $AccessToken";}
    $body = @{} | ConvertTo-Json # Pipeline doesn't require any parameters but we need to pass an empty JSON object or we'll get an error :(
    $response = Invoke-RestMethod -Method POST -Uri $startPipelineUri -Headers $headers -ContentType "application/json" -Body $body

    return $response.Id
}

function Get-PipelineStatus {
    param($RunId,
    $ExperimentName,
    $WorkspaceName,
    $SubscriptionId,
    $Location,
    $ResourceGroupName,
    $AccessToken)

    $statusUri = "https://$Location.experiments.azureml.net/history/v1.0/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.MachineLearningServices/workspaces/$WorkspaceName/experiments/$ExperimentName/runs/$RunId"
    Write-Host $statusUri
    $headers = @{Authorization="Bearer $AccessToken";}
    $response = Invoke-RestMethod -Method GET -Uri $statusUri -Headers $headers

    return $response.status
}

# Get an access token from Azure AD, for the service principal that has access to the AML workspace
function Get-AccessToken {
    param($ClientId,
    $ClientSecret,
    $TenantId)
  
    $loginUri = "https://login.microsoft.com/$TenantId/oauth2/v2.0/token"
    $postBody = @{client_id=$ClientId;client_secret=$ClientSecret;grant_type='client_credentials';scope='https://management.azure.com/.default'}
    $response = Invoke-RestMethod -Method POST -Uri $loginUri -Body $postBody -ContentType "application/x-www-form-urlencoded"

    return $response.access_token
}

# Invoke-Pipeline performs the following steps
# 1:  Get an Azure AD bearer token for our service principal
# 2:  Start the pipeline and return the run id
# 3:  Using the run id, check for status of the run
# 4:  If the run status is not 'completed' or 'failed', sleep.
# 5:  Repeate steps 3 and 4 until status is 'cmpleted' or 'failed'
# 6:  Set return code of script based on pipeline run final status.  'completed' = 0, 'failed' = 1
function Invoke-Pipeline {
    param(
        $ClientId,
        $ClientSecret,
        $TenantId,
        $PipelineId,
        $ExperimentName,
        $WorkspaceName,
        $ResourceGroupName,
        $Location,
        $SubscriptionId
    )

    $returnCode
    try {
        # Login with the service principal
        Write-Info -Text "Logging in with service principal"
        $accessToken = Get-AccessToken -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId
        
        # Start the pipeline and grab the run id so we can check status on it
        Write-Info -Text "Starting pipeline"
        $runId = Start-Pipeline -PipelineId $PipelineId -WorkspaceName $WorkspaceName -ResourceGroupName $ResourceGroupName -Location $Location -ExperimentName $ExperimentName -SubscriptionId $SubscriptionId -AccessToken $accessToken
        Write-Info "Pipeline started successfully, run id is $runId"
        $completed = $false

        do {
            $status = Get-PipelineStatus -RunId $runId -ExperimentName $ExperimentName -WorkspaceName $WorkspaceName -SubscriptionId $SubscriptionId -Location $Location -ResourceGroupName $ResourceGroupName -AccessToken $accessToken
            
            if ($status -eq "completed" -or $status -eq "failed")
            {
                Write-Info -Text "Pipeline has reached a final status of $status"
                $completed = $true
            } else {
                Write-Info -Text "Pipeline status is currently $status sleeping for $SecondsBetweenStatusCheck seconds"
                Start-Sleep $SecondsBetweenStatusCheck
            }    
        } until ($completed -eq $true)

        if ($status -eq "completed") {
            $returnCode = 0
          } else {
            $returnCode = 1
        }        
    }
    catch {
        Write-Error -Text "Error $_"
        $returnCode = 1
    }

    return $returnCode
}

function Write-Info {
    param($Text)
    Write-Host -ForegroundColor Green $Text
}

function Write-Error {
    param($Text)
    Write-Host -ForegroundColor Red $Text
}

$returnCode = Invoke-Pipeline -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId -PipelineId $PipelineId -ExperimentName $ExperimentName -WorkspaceName $WorkspaceName -ResourceGroupName $ResourceGroupName -Location $Location -SubscriptionId $SubscriptionId

Write-Info "Process completed, return code is $returnCode"
exit $returnCode