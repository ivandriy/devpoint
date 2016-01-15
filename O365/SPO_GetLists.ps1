param(

    [string]$UserName,

    [string]$Password
)

Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking
$SiteUrl = "https://ivanskiiy.sharepoint.com"

$UserName = "andrii@ivanskiiy.onmicrosoft.com"
$Password = "nomad_is_1593*"

$systemlibs =@("Converted Forms",
                "Customized Reports",
                "Form Templates", 
                "Images",
                 "List Template Gallery",
                 "Master Page Gallery",
                 "Pages",  
                 "Reporting Templates",
                 "Site Assets",
                 "Site Collection Documents",
                 "Site Collection Images",
                 "Site Pages",
                 "Solution Gallery",  
                 "Style Library",
                 "Theme Gallery",
                 "Web Part Gallery",
                 "wfpub",
                 "User Information List"
                 "appdata",
                 "Composed Looks",
                 "Content type publishing error log",
                 "MicroFeed",
                 "Project Policy Item List",
                 "TaxonomyHiddenList",
                 "Channel Settings",
                 "Settings",
                 "Videos",
                 "AppPages",
                 "Hub Settings",
                 "PortalSiteList",
                 "Cache Profiles",
                 "Content and Structure Reports",
                 "Device Channels",
                 "Long Running Operation Status",
                 "Notification List",
                 "Quick Deploy Items",
                 "Relationships List",
                 "Reusable Content",
                 "Suggested Content Browser Locations"
                 )
$SearchSiteUrl = $SiteUrl+"/search"

$match=$SiteUrl -match "https://\w+."
$MySiteUrl = ($Matches[0]).Replace(".","-my.")+"sharepoint.com/"

$PortalsCommSiteUrl = $SiteUrl+"/portals/community"
$PortalsHubSiteUrl = $SiteUrl+"/portals/hub"

$SitesToExclude = @($SearchSiteUrl,
                    $MySiteUrl,
                    $PortalsCommSiteUrl,
                    $PortalsHubSiteUrl
                    )
$Dir = Split-Path -parent $MyInvocation.MyCommand.Path
$DllsDir = $Dir+"\DLL"

Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.dll" 
Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.Runtime.dll"

function Get-SPOWebs()
{
param(

    [Microsoft.SharePoint.Client.ClientContext]$Context,
    [Microsoft.SharePoint.Client.Web]$RootWeb
)
  
  $childwebs = $rootweb.Webs
  $context.Load($childwebs)
  $context.ExecuteQuery()

  [Object[]]$allwebs = @()
  foreach($web in $childwebs)
  {
       Get-SPOWebs -Context $Context -RootWeb $web
       if(!([System.String]::IsNullOrWhiteSpace($web.Url )))
       {
           $webobj = New-Object PSObject
           [string]$isDevOrTest = ""
           $webobj|Add-Member -MemberType NoteProperty -Name Url -Value $web.Url
           $webobj|Add-Member -MemberType NoteProperty -Name Title -Value $web.Title
           $webobj|Add-Member -MemberType NoteProperty -Name IsRoot -Value "N"
           if($web.Url.Contains("dev") -or ($web.Url.Contains("test")))
           {
                $isDevOrTest = "Y"
           }
           else
           {
                $isDevOrTest = "N"
           }
           $webobj|Add-Member -MemberType NoteProperty -Name IsDevTest -Value $isDevOrTest
           $allwebs += $webobj 
        
       } 
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
    $sites = Get-SPOSite -Limit All|Where {$_.Url -notin $SitesToExclude}
}
catch
{
    Write-Host "Caught an exception while loading sites:" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red   
}

$AllLists=@()
$AllDoclibs = @()
foreach ($site in $sites)
{
    Write-Host "Processing: " $site.Url
    
    $surl = $site.Url
    $context = New-Object Microsoft.SharePoint.Client.ClientContext($surl)  
    $context.Credentials = $SPOCredentials
    [Microsoft.SharePoint.Client.Web]$web = $context.Web
    $context.Load($web)
    $context.ExecuteQuery()

    $Lists = $web.Lists
    $context.Load($Lists)
    $context.ExecuteQuery()

    foreach($list in $Lists)
    {
        if(-not ($systemlibs -Contains $list.Title))
        {
            $listobj=New-Object -TypeName PSObject
            $listobj| Add-Member -Name "WebURL" -MemberType Noteproperty -Value $web.URL
            $listobj| Add-Member -Name "Title" -MemberType Noteproperty -Value $list.Title
            $listobj| Add-Member -Name "ItemCount" -MemberType NoteProperty -Value $list.ItemCount
            $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate

            if($list.BaseTemplate -eq 101)
            {
                if($list.Title -eq "Documents")
                {
                    $listurl= $web.URL +"/Shared Documents"
                }
                else
                {
                    $listurl= $web.URL +"/"+ $list.Title    
                }
                $listobj| Add-Member -Name "Url" -MemberType NoteProperty -Value $listurl
                $AllDoclibs += $listobj
            }
            else
            {
                $listurl= $web.URL +"/Lists/"+ $list.Title
                $listobj| Add-Member -Name "Url" -MemberType NoteProperty -Value $listurl
                $AllLists +=$listobj
            }

        }

    }
    $subwebs = Get-SPOWebs -Context $context -RootWeb $web
    if($subwebs)
    {
        foreach ($subweb in $subwebs)
        {
            $surl = $subweb.Url
            $context = New-Object Microsoft.SharePoint.Client.ClientContext($surl)  
            $context.Credentials = $SPOCredentials
            [Microsoft.SharePoint.Client.Web]$web = $context.Web
            $context.Load($web)
            $context.ExecuteQuery()
            $Lists = $web.Lists
            $context.Load($Lists)
            foreach($list in $Lists)
            {
                if(-not ($systemlibs -Contains $list.Title))
                {
                    $listobj=New-Object -TypeName PSObject
                    $listobj| Add-Member -Name "WebURL" -MemberType Noteproperty -Value $web.URL
                    $listobj| Add-Member -Name "Title" -MemberType Noteproperty -Value $list.Title
                    $listobj| Add-Member -Name "ItemCount" -MemberType NoteProperty -Value $list.ItemCount
                    $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate

                    if($list.BaseTemplate -eq 101)
                    {
                        if($list.Title -eq "Documents")
                        {
                            $listurl= $web.URL +"/Shared Documents"
                        }
                        else
                        {
                            $listurl= $web.URL +"/"+ $list.Title    
                        }
                        $listobj| Add-Member -Name "Url" -MemberType NoteProperty -Value $listurl
                        $AllDoclibs += $listobj
                    }
                    else
                    {
                        $listurl= $web.URL +"/Lists/"+ $list.Title
                        $listobj| Add-Member -Name "Url" -MemberType NoteProperty -Value $listurl
                        $AllLists +=$listobj
                    }

                }

            }
                }        
        
    }
}

Write-Host "Libraries:"
$AllDoclibs|Format-Table -AutoSize -Wrap -Property Url,ItemCount,LastModified
Write-Host "============================================"
Write-Host
Write-Host "Lists:"
$AllLists|Format-Table -AutoSize -Wrap -Property Url,ItemCount,LastModified


Write-Host "Done!" -ForegroundColor Black -BackgroundColor Green
Write-Host
Write-Host "Script finished!" -ForegroundColor Black -BackgroundColor DarkGreen
