param(
    [parameter(Mandatory=$true)]
    [string]$SiteUrl,

    [parameter(Mandatory=$true)]
    [string]$UserName,

    [parameter(Mandatory=$true)]
    [string]$Password
)

Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking

$match=$SiteUrl -match "https://\w+."
$AdminSiteUrl = ($Matches[0]).Replace(".","-admin.")+"sharepoint.com"

$Creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $UserName, $(convertto-securestring $Password -asplaintext -force)

Connect-SPOService -Url $AdminSiteUrl -Credential $Creds

$sites=Get-SPOSite -Limit All -Detailed|Select -Property URL,WebsCount

[int]$TotalSubWebs= 0
foreach ($site in $sites)
{
    Write-Host "Site $($site.Url) have $($site.WebsCount) subweb(s)"
    $TotalSubWebs += [int]::Parse($site.WebsCount)
}
Write-Host "Total webs count: $($TotalSubWebs)"