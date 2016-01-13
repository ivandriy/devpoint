param
(   
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

function Export-ToCsvFile
{
    param(
        [Object[]]$ListToExport,
        $CsvFileName
    )

   if($ListToExport.Count -gt 0)
   {
     $CurrentDir = Split-Path -parent $script:MyInvocation.MyCommand.Path
     $SaveDir = $CurrentDir+"\Output"
     if(!(Test-Path $SaveDir))
     {
        New-Item -ItemType Directory -Force -Path $SaveDir|Out-Null
     }
                    
     $OutputFileName = $CsvFileName +".csv"
     $OutputFilePath = $SaveDir+"\"+$OutputFileName        
     if (Test-Path $OutputFilePath)
     {
        Remove-Item $OutputFilePath
     }
             
     $ListToExport|Export-Csv $OutputFilePath -NoTypeInformation
     Write-Host
     Write-Host "File saved to: $OutputFilePath"
               
   }
}


if ($PSVersionTable.PSVersion -lt [Version]"3.0") {
  powershell -Version 3 -File $MyInvocation.MyCommand.Definition $MossListsFile $O365SiteUrl $UserName $UserPassword
  exit
}

$Password = $UserPassword |ConvertTo-SecureString -AsPlainText -force
Write-Host
Write-Host "Loading SPO CSOM assemblies..."
$Dir = Split-Path -parent $MyInvocation.MyCommand.Path
$DllsDir = $Dir+"\DLL"
try
{
    Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.dll" 
    Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.Runtime.dll"   
}
catch
{
    Write-Host "Caught an exception while loading SPO CSOM assenblies:" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    return   
}

Write-Host
Write-Host "Trying to authenticate to O365 site $O365SiteUrl ..." 
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
}
catch
{
  Write-Host "Not able to authenticate to O365 site $O365SiteUrl" -ForegroundColor Red
  Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
  Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
  return
}

$SPOWebTitle = $web.Title
$CurrentDir = Split-Path -parent $MyInvocation.MyCommand.Path
$TargetDir = $CurrentDir+"\Output"
$SPOLists = @()
$MissedLists = @()
$ListsWithDiffItems = @()
$Docs = @()



$MossListsFile = $TargetDir+"\Lists.csv"
if(Test-Path -Path $MossListsFile -PathType Leaf)
{
    $MossLists = Import-Csv -Path $MossListsFile
    Write-Host
    Write-Host "Loaded - $($MossLists.Count) list(s) from $($MossListsFile)" 
}
else
{
    throw "File $($MossListsFile) was not found - please run MOSS_ExportLists.ps1 first!"
}


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
                 
                 if(!(Test-Path $TargetDir))
                 {
                     New-Item -ItemType Directory -Force -Path $TargetDir|Out-Null
                 }

                 $SaveDir = $TargetDir+"\SPO_Libraries"
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
             }
            
         }
                  

    }
    catch
    {
        $MissedLists += $mosslist
    }
    
}

$Tables = @()
if($MissedLists.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $MissedLists -CsvFileName "MissingLists"
   $Pre = "<h3>Missed Lists</h3>"
   $table = $MissedLists|ConvertTo-Html -PreContent $Pre -Fragment -Property Url,Title
   $table += "<td>"
   $Tables += $table
}

if ($ListsWithDiffItems.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $ListsWithDiffItems -CsvFileName "ModifiedLists"
   $Pre = "<h3>Modified Lists</h3>"
   $table = $ListsWithDiffItems|ConvertTo-Html -PreContent $Pre -Fragment Url,Title,SPOItemCount,MOSSItemCount
   $table += "<td>"
   $Tables += $table
}


$MossExportFolder = $TargetDir+"\MOSS_Libraries"
$SPOExportFolder = $TargetDir+"\SPO_Libraries"

$MossExportFiles = Get-ChildItem -Path $($MossExportFolder+"\*.*") -File -Include *.csv
$MissedDocs = @()
$ModifiedDocs = @()

foreach ($mossfile in $MossExportFiles)
{
    if (Test-Path $($SPOExportFolder+"\$($mossfile.Name)"))
    {
        
        $MossTable = Import-Csv -Path $mossfile.FullName
        $SPOTable = Import-Csv -Path $($SPOExportFolder+"\$($mossfile.Name)")

        $MossDocs=@{}
        $SPODocs = @{}

        foreach($line in $MossTable)
        {
            $MossDocs[$line.RelativeUrl]=$line
        }

        foreach($line in $SPOTable)
        {
            $SPODocs[$line.RelativeUrl]=$line
        }

        foreach ($doc in $MossDocs.Keys)
        {
            if($SPODocs.ContainsKey($doc))
            {
                $SPODocModDate = ($SPODocs.Item($doc)).Modified
                $MOSSDocModDate = ($MossDocs.Item($doc)).Modified
                $SPODocumentUrl = ($SPODocs.Item($doc)).Url
                $DocumentName = ($SPODocs.Item($doc)).Name
                $DocumentRelUrl = ($SPODocs.Item($doc)).RelativeUrl

                $docobj=New-Object -TypeName PSObject
                $docobj|Add-Member -Name "Name" -MemberType Noteproperty -Value $DocumentName
                $docobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $DocumentRelUrl
                $docobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $SPODocumentUrl
                $docobj|Add-Member -Name "MossModified" -MemberType Noteproperty -Value $MOSSDocModDate
                $docobj|Add-Member -Name "SPOModified" -MemberType Noteproperty -Value $SPODocModDate
                 
                if( $SPODocModDate -ne $MOSSDocModDate )
                {
                    $ModifiedDocs += $docobj  
                }
                else
                {
                    $OKDocs += $docobj  
                } 

            }
            else
            {
                $MissedDocs += $MossDocs.Item($doc)
            }
        }
        
    }
}

if($MissedDocs.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $MissedDocs -CsvFileName "MissingDocuments"
   $Pre = "<h3>Missed Documents</h3>"
   $table = $MissedDocs|ConvertTo-Html -PreContent $Pre -Fragment -Property Url
   $table += "<td>"
   $Tables += $table
}
        
if($ModifiedDocs.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $ModifiedDocs -CsvFileName "ModifiedDocuments"
   $Pre = "<h3>Modified Documents</h3>"
   $table = $ModifiedDocs|ConvertTo-Html -PreContent $Pre -Fragment -Property Url,MossModified,SPOModified
   $table += "<td>"
   $Tables += $table
}

$Head =
@"
    <style>
	BODY {
		font-family:Verdana; 
		background-color:white; 
		font-size:12px
	}
    TABLE {
        border-width: 1px;
        border-style: solid;
        border-color: black;
        border-collapse: collapse;
     }
     TH {
        font-size: 16px;
        font-weight: bold;
        text-align: left;
        color:white;
        font-family:Verdana;
        padding:5px;
        border-top:.5pt solid #93CDDD;
        border-right:.5pt solid #93CDDD;
        border-bottom:.5pt solid #93CDDD;
        border-left:.5pt solid #93CDDD;
        background:#4BACC6;
     }
     TD {
        font-size:12px;
        color:black;
        text-decoration:none;
        padding:5px;
        font-family:Verdana;
        border-top:.5pt solid #93CDDD;
        border-right:.5pt solid #93CDDD;
        border-left:.5pt solid #93CDDD;
        border-bottom:.5pt solid #93CDDD;
     }
    </style>
"@

$Body = @"
    <h3>Missing and modified lists/documents for site $($O365SiteUrl)
    <td>
    <br>
    <div align="right"><B>Report generated at $(get-date)</b></div><hr color=black height=10px align=left width=100%>
	<br>
"@

$HtmlReportFilePath = $CurrentDir+"\Report.html"
if($Tables)
{
    $Body += $Tables
    ConvertTo-Html -Head $Head -Body $Body -Title "Missing/modified items"|Out-File $HtmlReportFilePath
    Write-Host
    Write-Host "Report saved to: $HtmlReportFilePath" -ForegroundColor Green
}

Write-Host "Done!" -ForegroundColor Green