<# 
    Script sets lock statuts of MOSS2007 site collection

    Usage:
    
    .\Set-SiteLock.ps1 -Url http://moss -LockSite Readonly
    Sets http://moss site to readonly mode

    .\Set-SiteLock.ps1 -Url http://moss -LockSite None
    Reverts http://moss lock state to none (no lock)

#>

param(
[parameter(Mandatory=$true)]
[string]$Url,
[ValidateSet("None","Noadditions","Readonly","Noaccess")]
[string]$LockSite
)

Write-Host "Changing lock status at site - $($Url)..."
switch($LockSite)
{
    "None" {stsadm -o setsitelock -url $Url -lock none}
    "Noadditions" {stsadm -o setsitelock -url $Url -lock noadditions}
    "Readonly" {stsadm -o setsitelock -url $Url -lock readonly}
    "Noaccess" {stsadm -o setsitelock -url $Url -lock noaccess}
    default {"Lock option is not valid"}
}
stsadm -o getsitelock -url $Url
Write-Host "Done!"
