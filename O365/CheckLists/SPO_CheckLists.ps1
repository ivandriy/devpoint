param
(
    [parameter(Mandatory=$true)]
    [string]$MossListsFile,

    [parameter(Mandatory=$true)]
    [string]$O365SiteUrl,
    
    [parameter(Mandatory=$true)]
    [string]$UserName,

    [parameter(Mandatory=$true)]
    [string]$UserPassword
)

if ($PSVersionTable.PSVersion -ne [Version]"3.0") {
  powershell -Version 3 -File $MyInvocation.MyCommand.Definition $MossListsFile $O365SiteUrl $UserName $UserPassword
  exit
}

$Password = $UserPassword |ConvertTo-SecureString -AsPlainText -force
Write-Host "Load CSOM libraries" -ForegroundColor Black -BackgroundColor Yellow
$Dir = Split-Path -parent $MyInvocation.MyCommand.Path
$DllsDir = $Dir+"\DLL"
Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.dll" 
Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.Runtime.dll"
Write-Host "CSOM libraries loaded successfully" -ForegroundColor Black -BackgroundColor Green
Write-Host
Write-Host "Trying to authenticate to O365 site $O365SiteUrl ..." -ForegroundColor Black -BackgroundColor Yellow  
$context = New-Object Microsoft.SharePoint.Client.ClientContext($O365SiteUrl) 
$credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Username, $Password)
 
$context.Credentials = $credentials 
$context.RequestTimeOut = 5000 * 60 * 10;
$web = $context.Web
$site = $context.Site 
$context.Load($web)
$context.Load($site)
try
{
  $context.ExecuteQuery()
  Write-Host "Authenticated successfully" -ForegroundColor Black -BackgroundColor Green
}
catch
{
  Write-Host "Not able to authenticate to O365 site $O365SiteUrl - $_.Exception.Message" -ForegroundColor Black -BackgroundColor Red
  return
}

$SiteName = $web.Title
$SiteName = $SiteName.Replace(' ','_')

$MissedLists = @()
$OkLists = @()
$MissedItemsLists = @()
$ListsWithNewItems = @()
$NotMatchedLastModDateLists = @()

$MossLists = Import-Csv -Path $MossListsFile
Write-Host
Write-Host "Loaded - $($MossLists.Count) list(s) from $($MossListsFile)" -ForegroundColor Black -BackgroundColor Green
Write-Host

foreach ($mosslist in $MossLists)
{
    
    $O365SiteUrl = $O365SiteUrl.TrimEnd('/')+"/"
    $O365SiteUrl -match "https?://.*?/"|Out-Null
    $O365RootUrl = $Matches[0]

    $mossWeb = $mosslist.WebUrl
    $match=$mossWeb -match "https?://.*?/"
    $o365Web = ($mossWeb).Replace($Matches[0],$O365RootUrl)

    $context = New-Object Microsoft.SharePoint.Client.ClientContext($o365Web)  
    $context.Credentials = $credentials
    [Microsoft.SharePoint.Client.Web]$web = $context.Web
    [Microsoft.SharePoint.Client.List]$list = $web.Lists.GetByTitle($mosslist.Title)
    $context.Load($list)
    try
    {
         $context.ExecuteQuery()
         $listobj=New-Object -TypeName PSObject
         $listobj| Add-Member -Name "WebURL" -MemberType Noteproperty -Value $o365Web
         $listobj| Add-Member -Name "Title" -MemberType Noteproperty -Value $list.Title

         if($mosslist.Type -eq "List")
         {
            $listobj| Add-Member -Name "ItemCount" -MemberType NoteProperty -Value $list.ItemCount
            if($list.ItemCount -eq $mosslist.ItemCount)
             {
                $OkLists += $listobj
             }
             else
             {
                $listobj| Add-Member -Name "MossItemCount" -MemberType NoteProperty -Value $mosslist.ItemCount
                if($list.ItemCount -lt $mosslist.ItemCount)
                {
                    $listobj| Add-Member -Name "MissedItemCount" -MemberType NoteProperty -Value ($mosslist.ItemCount-$list.ItemCount)
                    $MissedItemsLists += $listobj
                }
                else
                {
                    $listobj| Add-Member -Name "AddedItemCount" -MemberType NoteProperty -Value ($list.ItemCount-$mosslist.ItemCount)
                    $ListsWithNewItems += $listobj
                }
                
             }

         }
         else
         {
            $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate
            if($list.LastItemModifiedDate -ne $mosslist.LastModified)
                {
                    $listobj| Add-Member -Name "MossLastModified" -MemberType NoteProperty -Value $mosslist.LastModified
                    $NotMatchedLastModDateLists += $listobj    
                }
             else
             {
                $OkLists += $listobj
             }

         }

    }
    catch
    {
        $MissedLists += $mosslist
    }
    
}

#For Output file generation
$SaveDir = Split-Path -parent $MyInvocation.MyCommand.Path

$MissedItemsListsReport = $SiteName + "_ListsWithMissedItems.csv"
$AddedItemsListsReport = $SiteName+"_ListsWithAddedItems.csv"
$LastModifiedListsReport = $SiteName + "_LibrariesWithNotMatchedLastModifiedDate.csv"
$MissedListsReport = $SiteName + "_MissedLists.csv"

if($MissedItemsLists.Count -ne 0)
{
    Write-Host "Found - $($MissedItemsLists.Count) list(s) with missed items:" -ForegroundColor Black -BackgroundColor Yellow  
    $MissedItemsLists|Format-Table -AutoSize -Wrap -Property WebUrl,Title,ItemCount,MossItemCount,MissedItemCount
    $OutputFilePath = $SaveDir+"\"+$MissedItemsListsReport
    if (Test-Path $OutputFilePath)
     {
        Remove-Item $OutputFilePath
     }
     $MissedItemsLists|Export-Csv $OutputFilePath -NoTypeInformation
     Write-Host "Report file saved at: $OutputFilePath"
     Write-Host 
}

if($ListsWithNewItems.Count -ne 0)
{
    Write-Host "Found - $($ListsWithNewItems.Count) list(s) with added items:" -ForegroundColor Black -BackgroundColor Yellow
    $ListsWithNewItems|Format-Table -AutoSize -Wrap -Property WebUrl,Title,ItemCount,MossItemCount,AddedItemCount
    $OutputFilePath = $SaveDir+"\"+$AddedItemsListsReport
    if (Test-Path $OutputFilePath)
     {
        Remove-Item $OutputFilePath
     }
     $ListsWithNewItems|Export-Csv $OutputFilePath -NoTypeInformation
     Write-Host "Report file saved at: $OutputFilePath"
     Write-Host
}

if ($NotMatchedLastModDateLists.Count -ne 0)
{
    Write-Host "Found - $($NotMatchedLastModDateLists.Count) librar(y/ies) with not matched LastModified date:" -ForegroundColor Black -BackgroundColor Yellow
    $NotMatchedLastModDateLists|Format-Table -AutoSize -Wrap -Property WebUrl,Title,LastModified,MossLastModified
    $OutputFilePath = $SaveDir+"\"+$LastModifiedListsReport
    if (Test-Path $OutputFilePath)
     {
        Remove-Item $OutputFilePath
     }
     $NotMatchedLastModDateLists|Export-Csv $OutputFilePath -NoTypeInformation
     Write-Host "Report file saved at: $OutputFilePath"
     Write-Host
}

if ($MissedLists.Count -ne 0)
{
    Write-Host "Found - $($MissedLists.Count) MOSS lists, missed on O365:" -ForegroundColor Black -BackgroundColor Yellow
    $MissedLists|Format-Table -AutoSize -Wrap -Property Url,Title
    $OutputFilePath = $SaveDir+"\"+$MissedListsReport
    if (Test-Path $OutputFilePath)
     {
        Remove-Item $OutputFilePath
     }
     $MissedLists|Export-Csv $OutputFilePath -NoTypeInformation
     Write-Host "Report file saved at: $OutputFilePath"
     Write-Host
}

if ($OKLists.Count -ne 0)
{
    Write-Host "Found - $($OKLists.Count) O365 lists, matched with MOSS lists:" -ForegroundColor Black -BackgroundColor Green
    $OKLists|Format-Table -AutoSize -Wrap -Property WebUrl,Title,ItemCount,LastModified
    Write-Host
}




