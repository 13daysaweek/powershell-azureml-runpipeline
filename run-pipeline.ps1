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

function Get-PipelineStatus {
    param($RunId,
    $ExperimentName,
    $WorkspaceName,
    $SubscriptionId,
    $Location,
    $ResourceGroupName,
    $AccessToken)

    $statusUri = "https://$Location/expieriments.azureml.net/history/v1.0/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.MachineLearningServices/$WorkspaceName/experiments/$ExperimentName/runs/$RunId"
    $headers = @{Authorization="Bearer $AccessToken";}
    $response = Invoke-RestMethod -Method GET -Uri $statusUri -Headers $headers
    $responseJson = $response | ConvertFrom-Json

    return $responseJson.status
}

# Get an access token from Azure AD, for the service principal that has access to the AML workspace
function Get-AccessToken {
    param($ClientId,
    $ClientSecret,
    $TenantId)
  
    $loginUri = "https://login.microsoft.com/$TenantId/oauth2/v2.0/token"
    $postBody = @{client_id=$ClientId;client_secret=$ClientSecret;grant_type='client_credentials';scope='https://management.azure.com/.default'}
    $response = Invoke-RestMethod -Method POST -Uri $loginUri -Body $postBody -ContentType "application/x-www-form-urlencoded"
    $responseJson = $response | ConvertFrom-Json
    
    return $responseJson.access_token
}

# Get-RunId parses the response that is returned by az cli when we start an Azure ML pipeline.  The first line of the response contains some text, including a GUID that is the run id.  The subsequent lines are
# JSON, which contains data about the submitted pipeline run.  This function pulls the guid out of the first line using a regex.
function Get-RunId {
    param($submitPipelineResponse)
    $lines = $submitPipelineResponse -split "\r\n"
    $runId = $lines[0] | Select-String -Pattern "[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}" -AllMatches | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value

    return $runId
}

function Invoke-AzCliLogout {
  az logout
}

# Start-Pipeline starts the Azure ML pipeline and returns the guid representing the run id in Azure ML.  The run id will be used later to check status of the run
function Start-Pipeline {
    param($PipelineId,
    $WorkspaceName,
    $ResourceGroupName)
    $response = az ml run submit-pipeline -i $PipelineId -w $WorkspaceName -g $ResourceGroupName

    $runId = Get-RunId($response)

    return $runId
}

# Invoke-Pipeline performs the following steps
# 1:  Login to az cli via service principal
# 2:  Start the pipeline and return the run id
# 3:  Using the run id, check for status of the run via az cli.
# 4:  If the run status is not 'completed' or 'failed', sleep.
# 5:  Repeate steps 3 and 4 until status is 'cmpleted' or 'failed'
# 6:  Set return code of script based on pipeline run final status.  'completed' = 0, 'failed' = 1
# 7:  logout of az cli
function Invoke-Pipeline {
    param(
        $ClientId,
        $ClientSecret,
        $TenantId,
        $PipelineId,
        $ExperimentName,
        $WorkspaceName,
        $ResourceGroupName
    )

    $returnCode
    try {
        # Login with the service principal
        Write-Info -Text "Logging in with service principal"
        Get-AccessToken -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId | Out-Null # Send this to null so it doesn't clobber the return code
        
        # Start the pipeline and grab the run id so we can check status on it
        Write-Info -Text "Starting pipeline"
        $runId = Start-Pipeline -PipelineId $PipelineId -WorkspaceName $WorkspaceName -ResourceGroupName $ResourceGroupName
        
        $completed = $false
        
        do {
            $status = Get-PipelineStatus -RunId $runId -ExperimentName $ExperimentName -WorkspaceName $WorkspaceName -ResourceGroupName $ResourceGroupName
            
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
    finally {
        Invoke-AzCliLogout
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

$returnCode = Invoke-Pipeline -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId -PipelineId $PipelineId -ExperimentName $ExperimentName -WorkspaceName $WorkspaceName -ResourceGroupName $ResourceGroupName

Write-Info "Process completed, return code is $returnCode"
exit $returnCode