param
(   
    [parameter(Mandatory=$true)]
    [string]$O365SiteUrl,
    
    [parameter(Mandatory=$true)]
    [string]$UserName,

    [parameter(Mandatory=$true)]
    [string]$UserPassword,

    [switch]
    $SingleWeb
)

#############FUNCTIONS###############
#region Functions
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
        $O365SiteUrl = $O365SiteUrl.TrimEnd('/')
        $O365SiteUrl -match "https?://.*?/"|Out-Null
        $O365RootUrl = $Matches[0]
        $O365RootUrl = $O365RootUrl.TrimEnd('/')
        $fileUrl = $O365RootUrl+$file.ServerRelativeUrl
                
        $fileobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $file.ServerRelativeUrl
        $fileobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $fileUrl
        
        $item = $file.ListItemAllFields
        $Context.Load($item)
        $Context.ExecuteQuery()
        $localModified = $item["Modified"]

        $fileobj|Add-Member -Name "Modified" -MemberType Noteproperty -Value $localModified        
        $files +=$fileobj
        Write-ToLogFile -Message "Document loaded. Name: $($file.ServerRelativeUrl); Last Modified: $($localModified)" -Path $LogFilePath -Level Info                          
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

function Write-ToLogFile
{
    
    param(
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()] 
        [string]$Message,
        
        [Parameter(Mandatory=$true)] 
        [string]$Path,
          
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info",

        [switch]
        $ConsoleOut
    )
    Begin 
    { 
    } 
    Process 
    {         
        if (!(Test-Path $Path)) 
        { 
            New-Item $Path -Force -ItemType File|Out-Null
        } 
        
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
        switch ($Level) { 
            'Error' {  
                $LevelText = 'ERROR:'
                $ForgroundCol = 'Red' 
                } 
            'Warn' {  
                $LevelText = 'WARNING:'
                $ForgroundCol = 'Yellow' 
                } 
            'Info' {  
                $LevelText = 'INFO:'
                $ForgroundCol = 'White' 
                } 
            }
        
        $OutputLine = "$FormattedDate $LevelText $Message"
        if($ConsoleOut) 
        {
            Write-Host  $Message -ForegroundColor $ForgroundCol    
        }
        $OutputLine| Out-File -FilePath $Path -Append
    } 
    End 
    {
     
    } 
}
#endregion

##############MAIN##################

#Check if PS runs on version 3.0
if ($PSVersionTable.PSVersion -lt [Version]"3.0") 
{
  if($SingleWeb)
  {
    powershell -Version 3 -File $MyInvocation.MyCommand.Definition $MossListsFile $O365SiteUrl $UserName $UserPassword -SingleWeb
  }
  else
  {
    powershell -Version 3 -File $MyInvocation.MyCommand.Definition $MossListsFile $O365SiteUrl $UserName $UserPassword
  }  
  exit
}

Write-Host
Write-Host "Current script version - #12" -ForegroundColor Green -BackgroundColor Black
$StartTime=Get-Date
Write-Host
Write-Host "Script started at $($StartTime)"
$sw = [Diagnostics.Stopwatch]::StartNew()

#Variables init
$CurrentDir = Split-Path -parent $MyInvocation.MyCommand.Path
$TargetDir = $CurrentDir+"\Output"
$FormattedDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFilePath = $TargetDir+"\SPO_ExportLists_$($FormattedDate).log"
$DllsDir = $CurrentDir+"\DLL"

Write-ToLogFile -Message "Current script version - #11" -Path $LogFilePath -Level Info
Write-ToLogFile -Message "Script started at $($StartTime)" -Path $LogFilePath -Level Info

#region Loading assemblies

Write-Host
#Write-Host "Loading SPO CSOM assemblies..."
Write-ToLogFile -Message "Loading SPO CSOM assemblies..." -Path $LogFilePath -Level Info -ConsoleOut
try
{
    Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.dll" 
    Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.Runtime.dll"
    Write-ToLogFile -Message "Done!" -Path $LogFilePath -Level Info -ConsoleOut
}
catch
{
    Write-ToLogFile -Message "Caught an exception while loading SPO CSOM assenblies:" -Path $LogFilePath -Level Error -ConsoleOut
    Write-ToLogFile -Message "Exception Type: $($_.Exception.GetType().FullName)" -Path $LogFilePath -Level Error -ConsoleOut
    Write-ToLogFile -Message "Exception Message: $($_.Exception.Message)" -Path $LogFilePath -Level Error -ConsoleOut
    return   
}
#endregion

#region Try O365 authentication
Write-Host
Write-ToLogFile -Message "Trying to authenticate to O365 site $O365SiteUrl ..." -Path $LogFilePath -Level Info -ConsoleOut
$context = New-Object Microsoft.SharePoint.Client.ClientContext($O365SiteUrl) 
$Password = $UserPassword |ConvertTo-SecureString -AsPlainText -force
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
  Write-ToLogFile -Message "Done!" -Path $LogFilePath -Level Info -ConsoleOut
}
catch
{
  Write-ToLogFile -Message "Not able to authenticate to O365 site $O365SiteUrl" -Path $LogFilePath -Level Error -ConsoleOut
  Write-ToLogFile -Message "Exception Type: $($_.Exception.GetType().FullName)" -Path $LogFilePath -Level Error -ConsoleOut
  Write-ToLogFile -Message "Exception Message: $($_.Exception.Message)" -Path $LogFilePath -Level Error -ConsoleOut
  return
}
#endregion

#Lists init
$SPOWebTitle = $web.Title
$SPOLists = @()
$MissedLists = @()
$ListsWithDiffItems = @()
$Docs = @()
$LibraryDocs = @()


$MossListsFile = $TargetDir+"\Lists.csv"
if(Test-Path -Path $MossListsFile -PathType Leaf)
{
    $MossLists = Import-Csv -Path $MossListsFile
    Write-Host
    Write-ToLogFile -Message "Loaded - $($MossLists.Count) list(s) from $($MossListsFile)" -Path $LogFilePath -Level Info -ConsoleOut
}
else
{
    throw "File $($MossListsFile) was not found - please run MOSS_ExportLists.ps1 first!"
}

Write-ToLogFile -Message "Start processing SPO items " -Path $LogFilePath -Level Info -ConsoleOut
#region Loading SPO items
foreach ($mosslist in $MossLists)
{
    $O365SiteUrl = $O365SiteUrl.TrimEnd('/')+"/"
    $mossWeb = $mosslist.WebUrl
    if($SingleWeb)
    {
        $o365Web = $O365SiteUrl
    }
    else
    {
        $O365SiteUrl -match "https?://.*?/"|Out-Null
        $O365RootUrl = $Matches[0]
        $match=$mossWeb -match "https?://.*?/"
        $o365Web = ($mossWeb).Replace($Matches[0],$O365RootUrl)
    }

    $listTitle = $mosslist.Title
    $context = New-Object Microsoft.SharePoint.Client.ClientContext($o365Web)  
    $context.Credentials = $credentials
    [Microsoft.SharePoint.Client.Web]$web = $context.Web
    $context.Load($web)
    try
    {
            $context.ExecuteQuery()
            $webTitle = $web.Title
            $webRelUrl = $web.ServerRelativeUrl
            [Microsoft.SharePoint.Client.List]$list = $web.Lists.GetByTitle($listTitle)
            Write-ToLogFile -Message "Trying to find list $($listTitle) on $o365Web by title" -Path $LogFilePath -Level Info
            $context.Load($list)
            try
            {
                 $context.ExecuteQuery()
                 $listobj=New-Object -TypeName PSObject
                 $listobj| Add-Member -Name "WebURL" -MemberType Noteproperty -Value $o365Web
                 $listobj| Add-Member -Name "Title" -MemberType Noteproperty -Value $list.Title
                 if($mosslist.Type -eq "List")
                 {
                    Write-ToLogFile -Message "List $($list.Title) loaded" -Path $LogFilePath -Level Info
                    $listurl = $o365Web+"Lists/"+ $list.Title
                    $listobj| Add-Member -Name "Url" -MemberType Noteproperty -Value $listurl
                    $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate
                    Write-ToLogFile -Message "LastItemModifiedDate: $($list.LastItemModifiedDate)" -Path $LogFilePath -Level Info
                    Write-ToLogFile -Message "Items: $($list.ItemCount)" -Path $LogFilePath -Level Info
                    if($list.ItemCount -ne $mosslist.ItemCount)
                    {
                        $listobj| Add-Member -Name "SPOItemCount" -MemberType NoteProperty -Value $list.ItemCount
                        $listobj| Add-Member -Name "MOSSItemCount" -MemberType NoteProperty -Value $mosslist.ItemCount
                        $ListsWithDiffItems += $listobj
                        Write-ToLogFile -Message "List items count differs! SPO count: [$($list.ItemCount)] MOSS count: [$($mosslist.ItemCount)]" -Path $LogFilePath -Level Warn
                    }
            
                 }
                 else
                 {  
            
                    Write-ToLogFile -Message "List $($list.Title) loaded" -Path $LogFilePath -Level Info
                    $listurl = $o365Web+ $list.Title
                    $listobj| Add-Member -Name "Url" -MemberType Noteproperty -Value $listurl
                    $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate
                    $listobj| Add-Member -Name "ItemCount" -MemberType NoteProperty -Value $list.ItemCount

                    Write-ToLogFile -Message "Last date modified: $($list.LastItemModifiedDate)" -Path $LogFilePath -Level Info
                    Write-ToLogFile -Message "Items: $($list.ItemCount)" -Path $LogFilePath -Level Info

                    $context.Load($list.RootFolder)
                    $context.ExecuteQuery()
                    $LibraryDocs += Get-FolderFiles -Folder $list.RootFolder -Context $context
                    $context.Load($list.RootFolder.Folders)
                    $context.ExecuteQuery()
                    foreach ($subFolder in $list.RootFolder.Folders)
                     {
                        $LibraryDocs += Recurse -Folder $subFolder -Context $context
                     }            
                 }
                  

            }
            catch
            {
        
                if($webRelUrl -eq "/")
                {
                    $RelUrl = "$($mosslist.RelativeUrl)"   
                }
                else
                {
                    $RelUrl = $webRelUrl+"/$($mosslist.RelativeUrl)"    
                }
        
                Write-ToLogFile -Message "Trying to find list $($listTitle) on web $($o365Web) by relative url $($RelUrl)" -Path $LogFilePath -Level Info
                [Microsoft.SharePoint.Client.List]$list = $web.GetList($RelUrl)
                $context.Load($list)
                try
                {
                         $context.ExecuteQuery();
                         $listobj=New-Object -TypeName PSObject
                         $listobj| Add-Member -Name "WebURL" -MemberType Noteproperty -Value $o365Web
                         $listobj| Add-Member -Name "Title" -MemberType Noteproperty -Value $list.Title
                         $context.Load($web)
                         $context.ExecuteQuery()
         
                         $webTitle = $web.Title
                         Write-Host $list.ParentWebUrl
                         if($mosslist.Type -eq "List")
                         {
                            Write-ToLogFile -Message "List $($list.Title) loaded" -Path $LogFilePath -Level Info
                            $listurl = $o365Web+"/$($mosslist.RelativeUrl)"
                            $listobj| Add-Member -Name "Url" -MemberType Noteproperty -Value $listurl
                            $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate
                            Write-ToLogFile -Message "LastItemModifiedDate: $($list.LastItemModifiedDate)" -Path $LogFilePath -Level Info
                            Write-ToLogFile -Message "Items: $($list.ItemCount)" -Path $LogFilePath -Level Info
                            if($list.ItemCount -ne $mosslist.ItemCount)
                            {
                                $listobj| Add-Member -Name "SPOItemCount" -MemberType NoteProperty -Value $list.ItemCount
                                $listobj| Add-Member -Name "MOSSItemCount" -MemberType NoteProperty -Value $mosslist.ItemCount
                                $ListsWithDiffItems += $listobj
                                Write-ToLogFile -Message "List items count differs! SPO count: [$($list.ItemCount)] MOSS count: [$($mosslist.ItemCount)]" -Path $LogFilePath -Level Warn
                            }
            
                         }
                         else
                         {  
            
                            Write-ToLogFile -Message "List $($list.Title) loaded" -Path $LogFilePath -Level Info
                            $listurl = $o365Web+"/$($mosslist.RelativeUrl)"
                            $listobj| Add-Member -Name "Url" -MemberType Noteproperty -Value $listurl
                            $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate
                            $listobj| Add-Member -Name "ItemCount" -MemberType NoteProperty -Value $list.ItemCount

                            Write-ToLogFile -Message "Last date modified: $($list.LastItemModifiedDate)" -Path $LogFilePath -Level Info
                            Write-ToLogFile -Message "Items: $($list.ItemCount)" -Path $LogFilePath -Level Info

                            $context.Load($list.RootFolder)
                            $context.ExecuteQuery()
                            $LibraryDocs += Get-FolderFiles -Folder $list.RootFolder -Context $context
                            $context.Load($list.RootFolder.Folders)
                            $context.ExecuteQuery()
                            foreach ($subFolder in $list.RootFolder.Folders)
                             {
                                $LibraryDocs += Recurse -Folder $subFolder -Context $context
                             }            
                         }
              
                    }
        catch
        {
            $MissedLists += $mosslist
            Write-ToLogFile -Message "List with title: $($listTitle) wasn't found on $($o365Web)" -Path $LogFilePath -Level Warn
         }    
    }
        
    }
    catch
    {
        Write-ToLogFile -Message "Web $($o365Web) wasn't found on SPO" -Path $LogFilePath -Level Warn
        $MissedLists += $MossLists|Where-Object { $_.WebUrl –eq $mossWeb }
        $MossLists = $MossLists|Where-Object { $_.WebUrl –ne $mossWeb }
    }
                
}
    
#endregion

if($LibraryDocs.Count -gt 0)
{
    Export-ToCsvFile -ListToExport $LibraryDocs -CsvFileName "SPODocuments"
}

#region Exporting SPO lists
$Tables = @()
if($MissedLists.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $MissedLists -CsvFileName "MissingLists"
   Write-ToLogFile -Message "Missed lists saved to $($CurrentDir)\Output\MissingLists.csv" -Path $LogFilePath -Level Info
   $Pre = "<h3>Missed Lists: $($MissedLists.Count) total</h3>"
   $table = $MissedLists|ConvertTo-Html -PreContent $Pre -Fragment -Property Url,Title
   $table += "<td>"
   $Tables += $table
}

if ($ListsWithDiffItems.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $ListsWithDiffItems -CsvFileName "ModifiedLists"
   Write-ToLogFile -Message "Modified lists saved to $($CurrentDir)\Output\ModifiedLists.csv" -Path $LogFilePath -Level Info
   $Pre = "<h3>Modified Lists: $($ListsWithDiffItems.Count) total</h3>"
   $table = $ListsWithDiffItems|ConvertTo-Html -PreContent $Pre -Fragment Url,Title,SPOItemCount,MOSSItemCount
   $table += "<td>"
   $Tables += $table
}
#endregion

#region Comparing documents
$MissedDocs = @()
$ModifiedDocs = @()
$MossDocumentsFile = $TargetDir+"\MossDocuments.csv"

Write-Host
Write-ToLogFile -Message "Loading MOSS documents from: $($MossDocumentsFile)" -Path $LogFilePath -Level Info
if(Test-Path $MossDocumentsFile)
{
    $MossTable = Import-Csv -Path $MossDocumentsFile    
}
else
{
    throw "File $($MossDocumentsFile) was not found - please run MOSS_ExportLists.ps1 first!"
}

$MossDocs=@{}
$SPODocs = @{}
$OKDocs = @()

foreach($line in $MossTable)
{
    $MossDocs[$line.RelativeUrl]=$line
}

foreach($doc in $LibraryDocs)
{
    $SPODocs[$doc.RelativeUrl]=$doc
}


foreach ($doc in $MossDocs.Keys)
        {

            if($SPODocs.ContainsKey($doc))
            {
                $SPODocumentUrl = ($SPODocs.Item($doc)).Url
                $DocumentName = ($SPODocs.Item($doc)).Name
                $DocumentRelUrl = ($SPODocs.Item($doc)).RelativeUrl

                Write-ToLogFile -Message "Processing document: $($DocumentRelUrl)" -Path $LogFilePath -Level Info
                
                $SPODocModDate = ($SPODocs.Item($doc)).Modified
                $MOSSDocModDate = ($MossDocs.Item($doc)).Modified
                Write-ToLogFile -Message "SPODocModDate: $($SPODocModDate); MOSSDocModDate: $($MOSSDocModDate)" -Path $LogFilePath -Level Info                                
                [System.Globalization.CultureInfo]$provider = [System.Globalization.CultureInfo]::InvariantCulture
                $format = "M/d/yyyy HH:mm:ss"
                [System.DateTime]$parsedDateMoss = get-date
                [System.DateTime]$parsedDateSpo = get-date
                [DateTime]::TryParseExact($MOSSDocModDate,$format,$provider,[System.Globalization.DateTimeStyles]::None,[ref]$parsedDateMoss)|Out-Null
                [DateTime]::TryParseExact($SPODocModDate,$format,$provider,[System.Globalization.DateTimeStyles]::None,[ref]$parsedDateSpo)|Out-Null
                Write-ToLogFile -Message "SPODocModDateParsed: $($parsedDateSpo); MOSSDocModDateParsed: $($parsedDateMoss)" -Path $LogFilePath -Level Info

                $docobj=New-Object -TypeName PSObject
                $docobj|Add-Member -Name "Name" -MemberType Noteproperty -Value $DocumentName
                $docobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $DocumentRelUrl
                $docobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $SPODocumentUrl
                $docobj|Add-Member -Name "MossModified" -MemberType Noteproperty -Value $parsedDateMoss.ToString($format)
                $docobj|Add-Member -Name "SPOModified" -MemberType Noteproperty -Value $parsedDateSpo.ToString($format)
                 
                if($parsedDateSpo -gt $parsedDateMoss)
                {
                    $ModifiedDocs += $docobj
                    Write-ToLogFile -Message "Document was modified on SPO! SPO LastModified: $($parsedDateSPO.ToString($format)); MOSS LastModified: $($parsedDateMOSS.ToString($format))" -Path $LogFilePath -Level Warn
                      
                }
                elseif ($parsedDateSpo -lt $parsedDateMoss)
                {
                   $ModifiedDocs += $docobj
                    Write-ToLogFile -Message "Document was modified on MOSS! MOSS LastModified: $($parsedDateMOSS.ToString($format)); SPO LastModified: $($parsedDateSPO.ToString($format)) " -Path $LogFilePath -Level Warn 
                }
                else
                {
                    $OKDocs += $docobj
                    Write-ToLogFile -Message "Last modified ok! SPO LastModified: $($parsedDateSPO.ToString($format)); MOSS LastModified: $($parsedDateMOSS.ToString($format))" -Path $LogFilePath -Level Info
                } 

            }
            else
            {
                $MissedDocs += $MossDocs.Item($doc)
                Write-ToLogFile -Message "Document was not found: $($doc)" -Path $LogFilePath -Level Warn
            }
        }


if($MissedDocs.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $MissedDocs -CsvFileName "MissingDocuments"
   Write-ToLogFile -Message "Missed documents saved to $($CurrentDir)\Output\MissingDocuments.csv" -Path $LogFilePath -Level Info
   $Pre = "<h3>Missed Documents: $($MissedDocs.Count) total</h3>"
   $table = $MissedDocs|ConvertTo-Html -PreContent $Pre -Fragment -Property Url,Modified
   $table += "<td>"
   $Tables += $table
}
        
if($ModifiedDocs.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $ModifiedDocs -CsvFileName "ModifiedDocuments"
   Write-ToLogFile -Message "Modified documents saved to $($CurrentDir)\Output\ModifiedDocuments.csv" -Path $LogFilePath -Level Info
   $Pre = "<h3>Modified Documents: $($ModifiedDocs.Count) total</h3>"
   $table = $ModifiedDocs|ConvertTo-Html -PreContent $Pre -Fragment -Property Url,MossModified,SPOModified
   $table += "<td>"
   $Tables += $table
}
#endregion

#region Make HTML report
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
    <br>
    <div align="right"><B>Report generated at $(get-date)</b></div><hr color=black height=10px align=left width=100%>
	<br>
    <h3>Missing and modified lists/documents for site $($O365SiteUrl)
    <td>
    <div align="left"><B>Total processed: $($MossLists.Count) lists</b></div><hr color=black height=10px align=left width=100%>
     
"@

$HtmlReportFilePath = $CurrentDir+"\Report.html"
if($Tables)
{
    $Body += $Tables
    ConvertTo-Html -Head $Head -Body $Body -Title "Missing/modified items"|Out-File $HtmlReportFilePath
    Write-Host
    Write-Host "Report saved to: $HtmlReportFilePath" -ForegroundColor Green
}
#endregion
$sw.Stop()
Write-Host "Total execution time: $($sw.Elapsed.Hours) hours $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec"
$FinishDate=Get-Date
Write-Host "Script finished at $($FinishDate)"
Write-Host "Done!" -ForegroundColor Green

Write-ToLogFile -Message "Total execution time: $($sw.Elapsed.Hours) hours $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec" -Path $LogFilePath -Level Info
Write-ToLogFile -Message "Script finished at $($FinishDate)" -Path $LogFilePath -Level Info
Write-ToLogFile -Message "Done!" -Path $LogFilePath -Level Info