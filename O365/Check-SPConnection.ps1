
param(
    [parameter(Mandatory=$true)]
    [string]$Url,
    [parameter(Mandatory=$true)]
    [string]$UserName,
    [parameter(Mandatory=$true)]
    [string]$Password
)

cls
Import-Module Sharegate

$secpwd = ConvertTo-SecureString $Password -AsPlainText -Force
try
{
    Write-Host "Connectiong to SPO site - $($Url)..."
    Connect-Site -Url $Url -UserName $UserName -Password $secpwd
    Write-Host -ForegroundColor Green "Done!"
    Write-Host -ForegroundColor Green "Your SPO site is available - finishing."
}
catch
{
    Write-Host "Error connecting to SPO site - $Url" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
} 
