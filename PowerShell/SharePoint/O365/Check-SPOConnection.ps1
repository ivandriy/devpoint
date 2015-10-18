
param(
    [string]$Url="https://miamiedu-admin.sharepoint.com",
    [parameter(Mandatory=$true)]
    [string]$UserName,
    [parameter(Mandatory=$true)]
    [string]$Password
)

cls
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking

$Creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $UserName, $(convertto-securestring $Password -asplaintext -force)

Write-Host "Connectiong to SPO admin service $($Url)..."

try
{
    Connect-SPOService -Url $Url -Credential $Creds
    Write-Host -ForegroundColor Green "Done!"
    Write-Host -ForegroundColor Green "Your SPO service is available - finishing."
}
catch
{
    Write-Host "Caught an exception connection to SPO:" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
}
