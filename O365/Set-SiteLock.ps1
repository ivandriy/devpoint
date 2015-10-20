<# 
    Script sets lock statuts of o365 site collection

    Usage:
    
    .\Set-SiteLock.ps1 -Url https://miamiedu.sharepoint.com/sites/site1 -LockSite NoAccess
    Disable access to https://miamiedu.sharepoint.com/sites/site1 site

    .\Set-SiteLock.ps1 -Url https://miamiedu.sharepoint.com/sites/site1 -LockSite Unlock
    Reverts access to https://miamiedu.sharepoint.com/sites/site1 site

#>


param(
    [parameter(Mandatory=$true)]
    [string]$Url,
    [ValidateSet("NoAccess","Unlock")]
    [string]$LockSite
)

Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking


$Username = Read-Host "Enter username: "
$Password = Read-Host "Enter password: " -AsSecureString

$Creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $UserName, $Password

Connect-SPOService -Url https://miamiedu-admin.sharepoint.com -Credential $Creds

Write-Host "Setting lock [$($LockSite)] on site $($LockSite)..."
Set-SPOSite -Identity $Url -LockState $LockSite
Write-Host "Done!"