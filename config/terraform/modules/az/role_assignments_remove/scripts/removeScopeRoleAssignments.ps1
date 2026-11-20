# remove all role assignments from a resource scope
param(
    [Parameter(Mandatory = $false)] [switch] $develop = $false
)

if ($develop) {
    # The story here is "remove all role assignments from dev-jom's storage container, but before doing so,
    # make sure that AzDO-SC-ddi-stg-o has `Owner PGGM` on the subscription above"
    $check_before = @(
        @{
            principalId        = "67cf310a-9619-4192-b743-40ef8c14c98e"   # AzDO-SC-pggmstgsf-o
            principalType      = "ServicePrincipal"
            roleDefinitionName = "Owner PGGM"
            scope              = "/subscriptions/08657613-f381-40de-b239-49204a1e9f1e"
        }
    )
    $azcli_credentials = @{
        subscription_id = "08657613-f381-40de-b239-49204a1e9f1e"
        tenant_id       = "9e3ee5fe-3a99-45db-ac6e-691e86febef3"
        client_id       = "22cdab63-d557-416b-826e-f97e757f06d1"
        client_secret   = ""
    }
    $resource_scope = "/subscriptions/08657613-f381-40de-b239-49204a1e9f1e/resourceGroups/rg-pggmstgsf-lz-o/providers/Microsoft.Storage/storageAccounts/sapggmstgsflzo/blobServices/default/containers/dev-jom"
    $env:resource_scope = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($resource_scope))
    $env:check_before = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($check_before | ConvertTo-Json -AsArray)))
    $env:azcli_credentials = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($azcli_credentials | ConvertTo-Json)))
    # -AsArray and -NoEnumerate are required to have single-item arrays
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# required environment variables
if (-not $env:resource_scope) {
    throw "Environment variable 'resource_scope' is not set."
}
if (-not $env:check_before) {
    throw "Environment variable 'check_before' is not set."
}
if (-not $env:azcli_credentials) {
    throw "Environment variable 'azcli_credentials' is not set."
}
$resource_scope = [Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:resource_scope))
$check_before = [Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:check_before)) | ConvertFrom-Json -AsHashtable -NoEnumerate
$azcli_credentials = [Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:azcli_credentials)) | ConvertFrom-Json -AsHashtable -NoEnumerate

# Login to Azure CLI. Set AZURE_CONFIG_DIR so we can have multiple logins at the same agent / time
if ($env:LOCALAPPDATA) {
    $env:AZURE_CONFIG_DIR = "$env:LOCALAPPDATA/$(New-Guid)"
}
else {
    $env:AZURE_CONFIG_DIR = "$env:HOME/$(New-Guid)"
}
Write-Host("Set AZURE_CONFIG_DIR to $($env:AZURE_CONFIG_DIR)")
az login --service-principal --username $azcli_credentials.client_id --tenant $azcli_credentials.tenant_id --password $azcli_credentials.client_secret --allow-no-subscriptions
if ($? -eq $false) {
    throw "Failed to login to Azure CLI"
}
az account set --subscription $azcli_credentials.subscription_id
if ($? -eq $false) {
    throw "Failed to set subscription in Azure CLI"
}
Write-Host "Logged in using provided credentials"

if ($develop) {
    Write-Host "Resource scope:"
    $resource_scope
    Write-Host "Check before:"
    $check_before | ConvertTo-JSON
}

# Check role assignments prior to removal
$matchedRoleCount = 0
foreach ($checkRa in $check_before) {
    $assignments = $(az role assignment list --scope $checkRa.scope) | ConvertFrom-Json -AsHashtable
    if ($? -eq $false) {
        throw("Failed to `'az role assignment list --scope $checkRa.scope`'")
    }
    foreach ($ra in $assignments) {
        if (($ra.principalId -eq $checkRa.principalId) -and
            ($ra.roleDefinitionName -eq $checkRa.roleDefinitionName) -and
            ($ra.principalType -eq $checkRa.principalType)) {
            $matchedRoleCount ++
            Write-Host("Role '$($ra.roleDefinitionName)' on scope '$($checkRa.scope)' for '$($ra.principalId)' exists")
        }
    }
}

if ($matchedRoleCount -ne $check_before.Count) {
    throw("check_before requirement not met: expected $($check_before.Count) matching role assignments, found $matchedRoleCount")
}
# Remove all role assignments from the resource scope
$assignments = $(az role assignment list --scope $resource_scope) | ConvertFrom-Json -AsHashTable
if ($? -eq $false) {
    throw("Failed to `'az role assignment list --scope $resource_scope`'")
}
Write-Host "Assignments to removed:"
$assignments | ConvertTo-JSON

foreach ($assignment in $assignments) {
    az role assignment delete --ids $assignment.id
    if ($? -eq $false) {
        throw "Failed to remove assignment"
    }
}
