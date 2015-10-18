param(
    [parameter(Mandatory=$true)]
    [string]$SiteUrl,

    [parameter(Mandatory=$true)]
    [string]$ListName,

    [parameter(Mandatory=$true)]
    [string]$UserName,

    [parameter(Mandatory=$true)]
    [string]$Password
)

Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking

$Dir = Split-Path -parent $MyInvocation.MyCommand.Path
$DllsDir = $Dir+"\DLL"

Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.dll" 
Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.Runtime.dll"

function Get-SPOWebs()
{
param(
   $Url = $(throw "Please provide a Site Collection Url"),
   $Credential = $(throw "Please provide a Credentials")
)
  
  Write-Host "Loading subwebs for site $($Url)"
  $context = New-Object Microsoft.SharePoint.Client.ClientContext($Url)  
  $context.Credentials = $Credential
   
  $rootweb = $context.Web
  $context.Load($rootweb)

  $childwebs = $rootweb.Webs
  $context.Load($childwebs)

  $context.ExecuteQuery()

  [Object[]]$allwebs = @()
  $allwebs += $rootweb
  foreach($web in $childwebs)
  {
       $allwebs +=$web
  }
 
  return $allwebs
}

$match=$SiteUrl -match "https://\w+."
$AdminSiteUrl = ($Matches[0]).Replace(".","-admin.")+"sharepoint.com"

$Creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $UserName, $(convertto-securestring $Password -asplaintext -force)
$SecurePassword = New-Object System.Security.SecureString
$SecureArray = $Password.ToCharArray()
foreach ($char in $SecureArray)
{
    $SecurePassword.AppendChar($char)
}
#$SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force

$SPOCredentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($UserName, $SecurePassword)

Write-Host "Script starting" -BackgroundColor Black -ForegroundColor Yellow
Write-Host
Write-Host "Connecting to SPO admin service $($AdminSiteUrl)..." -ForegroundColor Yellow

try
{
    Connect-SPOService -Url $AdminSiteUrl -Credential $Creds
    Write-Host "Done!" -ForegroundColor Black -BackgroundColor Green
}
catch
{
    Write-Host "Caught an exception connection to SPO:" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Loading all sites and webs" -ForegroundColor Yellow

try
{
    $sites = Get-SPOSite -Limit All   
}
catch
{
    Write-Host "Caught an exception while loading sites:" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red   
}

$allwebs = @()
foreach ($site in $sites)
{
    $subwebs=@()
    $surl = $site.Url
    Write-Host "============================================"
    $subwebs = Get-SPOWebs -Url $site.Url -Credential $SPOCredentials
    if($subwebs)
    {
        Write-Host "Site $($surl) have $($subwebs.Count) web(s): " -ForegroundColor Green
        foreach ($web in $subwebs)
        {
            $allwebs += $web
            Write-Host "  "$web.Url -ForegroundColor Yellow
        }
        Write-Host "============================================"
        Write-Host
        
    }
}

$WebsCount = $allwebs.Count
$SitesCount = $sites.Count

if($WebsCount -gt 0)
{
    Write-Host "Done - loaded $($WebsCount) webs for $($SitesCount) sites" -ForegroundColor Black -BackgroundColor Green
}
else
{
    throw "Can't retrive webs"
}

$SaveDir = $env:TEMP
$ReportFile = $SaveDir+"\allwebs.txt"
$allwebs|ForEach {$_.Url} |Out-File $ReportFile
Write-Host "Report is saved at - $($ReportFile)"

<#Write-Host "Connecting to destination site $($SiteUrl) with list $($ListName)" -ForegroundColor Yellow
try
{
    $context = New-Object Microsoft.SharePoint.Client.ClientContext($SiteUrl)  
    $context.Credentials = $SPOCredentials
    [Microsoft.SharePoint.Client.Web]$web = $context.Web
    [Microsoft.SharePoint.Client.List]$list = $web.Lists.GetByTitle($ListName)
    $context.Load($list)
    $context.ExecuteQuery()
    Write-Host "Done!" -ForegroundColor Black -BackgroundColor Green   
}

catch
{
    Write-Host "Caught an exception while connecting to site $($SiteUrl):" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red   
}


Write-Host "Deleting existing items in $($ListName)" -ForegroundColor Yellow
$continue = $true
while($continue)
{
    $query = [Microsoft.SharePoint.Client.CamlQuery]::CreateAllItemsQuery(100, "ID")
    $listItems = $list.GetItems( $query )
    $context.Load($listItems)
    $context.ExecuteQuery()       
    if ($listItems.Count -gt 0)
    {
        for ($i = $listItems.Count-1; $i -ge 0; $i--)
        {
            $listItems[$i].DeleteObject()
        } 
        $context.ExecuteQuery()
    }
    else
    {
        $continue = $false;
    }
}
Write-Host "Done!" -ForegroundColor Black -BackgroundColor Green

$ItemsCount = $WebsCount
Write-Host "Adding $($ItemsCount) items into list $($ListName)" -ForegroundColor Yellow
foreach ($web in $allwebs) 
{
    [Microsoft.SharePoint.Client.ListItemCreationInformation]$itemCreateInfo = New-Object Microsoft.SharePoint.Client.ListItemCreationInformation
    [Microsoft.SharePoint.Client.ListItem]$item = $list.AddItem($itemCreateInfo)
    $item["Title"] = $web.Title
    $item["SiteURL"] = $web.URL

    $item.Update()

    $context.ExecuteQuery()
}#>
Write-Host "Done!" -ForegroundColor Black -BackgroundColor Green
Write-Host
Write-Host "Script finished!" -ForegroundColor Black -BackgroundColor DarkGreen
