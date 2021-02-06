[cmdletbinding()]
param(
    [parameter(mandatory="true")]
    [string] $ClientId,
    [parameter(mandatory="true")]
    [string] $ClientSecret,
    [parameter(mandatory="true")]
    [string] $TenantId,
    [parameter(mandatory="true")]
    [string] $PipelineName,
    [parameter(mandatory="true")]
    [string] $WorkspaceName,
    [parameter(mandatory="true")]
    [string] $ResourceGroupName
)

# Login with the service principal
az login --service-principal --username $ClientId --password $ClientSecret --tenant $TenantId
