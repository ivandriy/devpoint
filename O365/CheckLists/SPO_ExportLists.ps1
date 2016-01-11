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


function Recurse 
{
    param(
        [Microsoft.SharePoint.Client.Folder]$Folder,
        [Microsoft.SharePoint.Client.ClientContext]$Context
        )
     
    [Object[]]$AllFiles = @()   
    $folderName = $Folder.Name
    $folderItemCount = $folder.ItemCount

    if($Folder.name -ne "Forms")
        {
            $AllFiles += Get-FolderFiles -Folder $Folder -Context $Context
            $thisFolder = $Context.Web.GetFolderByServerRelativeUrl($folder.ServerRelativeUrl)
            $Context.Load($thisFolder)
            $Context.Load($thisFolder.Folders)
            $Context.ExecuteQuery()
            
            foreach($subfolder in $thisFolder.Folders)
                {
                    $AllFiles += Recurse -Folder $subfolder -Context $Context 
                }
        }

    return $AllFiles           
}

function Get-FolderFiles
{
    param(
        [Microsoft.SharePoint.Client.Folder]$Folder,
        [Microsoft.SharePoint.Client.ClientContext]$Context
    )

    $Context.Load($Folder.Files)
    $Context.ExecuteQuery()
    
    [Object[]]$files = @()
    foreach ($file in $Folder.Files)
    {
        $fileobj=New-Object -TypeName PSObject
        $fileobj|Add-Member -Name "Name" -MemberType Noteproperty -Value $file.name
        $fileUrl = $O365SiteUrl.TrimEnd('/')+$file.ServerRelativeUrl

        $fileobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $file.ServerRelativeUrl
        $fileobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $fileUrl

        $fileobj|Add-Member -Name "Modified" -MemberType Noteproperty -Value $file.TimeLastModified
        $files +=$fileobj                          
    }
    return $files
}


if ($PSVersionTable.PSVersion -lt [Version]"3.0") {
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

$SPOWebTitle = $web.Title

$SPOLists = @()
$MissedLists = @()
$ListsWithDiffItems = @()
$Docs = @()

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
         
         $context.Load($web)
         $context.ExecuteQuery()
         $webTitle = $web.Title
         if($mosslist.Type -eq "List")
         {
            $listurl = $o365Web+"Lists/"+ $list.Title
            $listobj| Add-Member -Name "Url" -MemberType Noteproperty -Value $listurl
            $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate
            if($list.ItemCount -ne $mosslist.ItemCount)
            {
                $listobj| Add-Member -Name "SPOItemCount" -MemberType NoteProperty -Value $list.ItemCount
                $listobj| Add-Member -Name "MOSSItemCount" -MemberType NoteProperty -Value $mosslist.ItemCount
                $ListsWithDiffItems += $listobj
            }
         }
         else
         {  
            $LibraryDocs = @()

            $listurl = $o365Web+ $list.Title
            $listobj| Add-Member -Name "Url" -MemberType Noteproperty -Value $listurl
            $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate
            $listobj| Add-Member -Name "ItemCount" -MemberType NoteProperty -Value $list.ItemCount

            $context.Load($list.RootFolder)
            $context.ExecuteQuery()
            $LibraryDocs += Get-FolderFiles -Folder $list.RootFolder -Context $context
            $context.Load($list.RootFolder.Folders)
            $context.ExecuteQuery()
            foreach ($subFolder in $list.RootFolder.Folders)
             {
                $LibraryDocs += Recurse -Folder $subFolder -Context $context
             }

             if($LibraryDocs.Count -gt 0)
             {
                 $CurrentDir = Split-Path -parent $MyInvocation.MyCommand.Path
                 $SaveDir = $CurrentDir+"\SPO_Libraries"
                 if(!(Test-Path $SaveDir))
                 {
                    New-Item -ItemType Directory -Force -Path $SaveDir|Out-Null
                 }
                    
                 $OutputFileName = $webTitle +"_"+$list.Title+".csv"
                 $OutputFilePath = $SaveDir+"\"+$OutputFileName
             
                 $listobj| Add-Member -Name "ItemsFilePath" -MemberType NoteProperty -Value $OutputFilePath
                 if (Test-Path $OutputFilePath)
                 {
                    Remove-Item $OutputFilePath
                 }
             
                 $LibraryDocs|Export-Csv $OutputFilePath -NoTypeInformation
                 Write-Host "Library [$($list.Title)] exported to: $OutputFilePath"
                 Write-Host     
             }
            
         }
                  

    }
    catch
    {
        $MissedLists += $mosslist
    }
    
}


$SaveDir = Split-Path -parent $MyInvocation.MyCommand.Path

if($MissedLists.Count -gt 0)
{
   $OutputFileName = "SPO_"+$SPOWebTitle + "_MissedLists.csv"
    $OutputFilePath = $SaveDir+"\"+$OutputFileName
    #delete the file, If already exist!
    if (Test-Path $OutputFilePath)
     {
        Remove-Item $OutputFilePath
     }

    $MissedLists|Export-Csv $OutputFilePath -NoTypeInformation
    Write-Host "Missed lists report saved to: $OutputFilePath"
    Write-Host 
}

if ($ListsWithDiffItems.Count -gt 0)
{
   $OutputFileName = "SPO_"+$SPOWebTitle + "_ListsWithDiffItems.csv"
    $OutputFilePath = $SaveDir+"\"+$OutputFileName
    #delete the file, If already exist!
    if (Test-Path $OutputFilePath)
     {
        Remove-Item $OutputFilePath
     }

    $ListsWithDiffItems|Export-Csv $OutputFilePath -NoTypeInformation
    Write-Host "Report for lists with different item count saved to: $OutputFilePath"
    Write-Host 
}
