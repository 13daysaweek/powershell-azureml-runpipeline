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
    [int] $SecondsBetweenStatusCheck = 60
)

function Get-RunId {
    param($submitPipelineResponse)
    $lines = $submitPipelineResponse -split "\r\n"
    $runId = $lines[0] | Select-String -Pattern "[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}" -AllMatches | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value

    return $runId
}

function Get-AccessToken {
    param($ClientId,
    $ClientSecret,
    $TenantId)

    az login --service-principal --username $ClientId --password $ClientSecret --tenant $TenantId
}

function Start-Pipeline {
    param($PipelineId,
    $WorkspaceName,
    $ResourceGroupName)
    $response = az ml run submit-pipeline -i $PipelineId -w $WorkspaceName -g $ResourceGroupName

    $runId = Get-RunId($response)

    return $runId
}

function Get-PipelineStatus {
  param($RunId,
  $ExperimentName,
  $WorkspaceName,
  $ResourceGroupName)

  $status = az ml run show -r $RunId -w $WorkspaceName -g $ResourceGroupName -e $ExperimentName
  $json = $status | ConvertFrom-Json
  return $json.status
}

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

  $returnCode
  if ($status -eq "completed") {
    $returnCode = 0
  } else {
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

$returnCode = Invoke-Pipeline -ClientId $ClientId -ClientSecret $ClientSecret -TenantId $TenantId -PipelineId $PipelineId -ExperimentName $ExperimentName -WorkspaceName $WorkspaceName -ResourceGroupName $ResourceGroupName

Write-Info "Process completed, return code is $returnCode"
exit $returnCode