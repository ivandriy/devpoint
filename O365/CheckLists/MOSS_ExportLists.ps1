param
(
    [parameter(Mandatory=$true)]
    [string]$MossSiteUrl,
    [switch]$SingleWeb
)

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


if ($PSVersionTable.PSVersion -gt [Version]"2.0") 
{
  if($SingleWeb)
  {
    powershell -Version 2 -File $MyInvocation.MyCommand.Definition $MossSiteUrl -SingleWeb
  }  
  else
  {
    powershell -Version 2 -File $MyInvocation.MyCommand.Definition $MossSiteUrl
  }
  exit
}

Write-Host
Write-Host "Current script version - #11" -ForegroundColor Green -BackgroundColor Black

$MossLists = @()
$Docs = @()
$CurrentDir = Split-Path -parent $MyInvocation.MyCommand.Path
$TargetDir = $CurrentDir+"\Output"
$FormattedDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFilePath = $TargetDir+"\MOSS_ExportLists_$($FormattedDate).log"
$format = "M/d/yyyy HH:mm:ss"

Write-ToLogFile -Message "Current script version - #11" -Path $LogFilePath -Level Info
Write-Host
Write-ToLogFile -Message "Loading MOSS PowerShell assembly..." -Path $LogFilePath -Level Info -ConsoleOut
try
{
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
    Write-ToLogFile -Message "Done!" -Path $LogFilePath -Level Info -ConsoleOut    
}
catch
{
    Write-ToLogFile -Message "Caught an exception while loading SPO CSOM assenblies:" -Path $LogFilePath -Level Error -ConsoleOut

    Write-ToLogFile -Message "Caught an exception while loading MOSS assenbly:" -Path $LogFilePath -Level Error -ConsoleOut
    Write-ToLogFile -Message "Exception Type: $($_.Exception.GetType().FullName)" -Path $LogFilePath -Level Error -ConsoleOut
    Write-ToLogFile -Message "Exception Message: $($_.Exception.Message)" -Path $LogFilePath -Level Error -ConsoleOut
    return    
}

$systemlibs =@("Converted Forms", "Customized Reports", "Form Templates",  
                              "Images", "List Template Gallery", "Master Page Gallery", "Pages",  
                               "Reporting Templates", "Site Assets", "Site Collection Documents", 
                               "Site Collection Images", "Site Pages", "Solution Gallery",  
                               "Style Library", "Theme Gallery", "Web Part Gallery", "wfpub","User Information List","Workflows","Workflow History","Tasks")



Write-Host
Write-ToLogFile -Message "Starting export lists from site: $MossSiteUrl" -Path $LogFilePath -Level Info -ConsoleOut

if($SingleWeb)
{
        $web = (New-Object Microsoft.SharePoint.SPSite($MossSiteUrl)).OpenWeb()
        foreach($list in $web.Lists)
        {
            if((-not ($systemlibs -Contains $list.Title)) -and ($list.ItemCount -gt 0))
            {
                $listobj=New-Object -TypeName PSObject
                $webUrl = $web.URL+"/"
                $listobj| Add-Member -Name "WebURL" -MemberType Noteproperty -Value $webUrl
                $listobj| Add-Member -Name "Title" -MemberType Noteproperty -Value $list.Title
                $listurl= $web.URL +"/"+ $list.RootFolder.Url
                Write-ToLogFile -Message "Processing list $($listurl)" -Path $LogFilePath -Level Info
                $listobj| Add-Member -Name "Url" -MemberType NoteProperty -Value $listurl
                $listobj| Add-Member -Name "RelativeUrl" -MemberType NoteProperty -Value $list.RootFolder.Url
                $listLastModFormated = ($list.LastItemModifiedDate).ToString($format)
                $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $listLastModFormated
                $listobj| Add-Member -Name "ItemCount" -MemberType NoteProperty -Value $list.ItemCount
                Write-ToLogFile -Message "LastItemModifiedDate: $($listLastModFormated)" -Path $LogFilePath -Level Info
                Write-ToLogFile -Message "Items: $($list.ItemCount)" -Path $LogFilePath -Level Info 

                if($list.BaseTemplate -eq "DocumentLibrary")
                {
                    $listobj| Add-Member -Name "Type" -MemberType NoteProperty -Value "Library"
                    
                    foreach($item in $list.Items)
                    {
                        $itemobj=New-Object -TypeName PSObject
                        $itemobj|Add-Member -Name "Name" -MemberType Noteproperty -Value $item["Name"]
                        $itemRelUrl = $item["ServerUrl"]                       
                        $itemobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $itemRelUrl
                        $itemobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $item["ows_EncodedAbsUrl"]
                        $localModified = $item["Modified"]
                        $localModifiedFormated = $localModified.ToString($format)
                        $itemobj|Add-Member -Name "Modified" -MemberType Noteproperty -Value $localModifiedFormated
                        Write-ToLogFile -Message "Document loaded. Name: $($itemRelUrl); LastModified: $($localModifiedFormated)" -Path $LogFilePath -Level Info 
                        $Docs += $itemobj
                    }
                                          
                }
                else
                {
                    $listobj| Add-Member -Name "Type" -MemberType NoteProperty -Value "List"
                    
                }  
                
                $MossLists += $listobj
            }   
        }
        $web.Dispose()
     
}
else
{
    $site = New-Object Microsoft.SharePoint.SPSite($MossSiteUrl)
    foreach ($web in $site.AllWebs)
    {
        $webobj=$site.OpenWeb()
        foreach($list in $web.Lists)
        {
            if((-not ($systemlibs -Contains $list.Title)) -and ($list.ItemCount -gt 0))
            {
                $listobj=New-Object -TypeName PSObject
                $webUrl = $web.URL+"/"
                $listobj| Add-Member -Name "WebURL" -MemberType Noteproperty -Value $webUrl
                $listobj| Add-Member -Name "Title" -MemberType Noteproperty -Value $list.Title
                $listurl= $web.URL +"/"+ $list.RootFolder.Url
                Write-ToLogFile -Message "Processing list $($listurl)" -Path $LogFilePath -Level Info
                $listobj| Add-Member -Name "Url" -MemberType NoteProperty -Value $listurl
                $listobj| Add-Member -Name "RelativeUrl" -MemberType NoteProperty -Value $list.RootFolder.Url
                $listLastModFormated = ($list.LastItemModifiedDate).ToString($format)
                $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $listLastModFormated
                $listobj| Add-Member -Name "ItemCount" -MemberType NoteProperty -Value $list.ItemCount
                Write-ToLogFile -Message "LastItemModifiedDate: $($listLastModFormated)" -Path $LogFilePath -Level Info
                Write-ToLogFile -Message "Items: $($list.ItemCount)" -Path $LogFilePath -Level Info 

                if($list.BaseTemplate -eq "DocumentLibrary")
                {
                    $listobj| Add-Member -Name "Type" -MemberType NoteProperty -Value "Library"
                    
                    foreach($item in $list.Items)
                    {
                        $itemobj=New-Object -TypeName PSObject
                        $itemobj|Add-Member -Name "Name" -MemberType Noteproperty -Value $item["Name"]
                        $itemRelUrl = $item["ServerUrl"]                       
                        $itemobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $itemRelUrl
                        $itemobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $item["ows_EncodedAbsUrl"]
                        $localModified = $item["Modified"]
                        $localModifiedFormated = $localModified.ToString($format)
                        $itemobj|Add-Member -Name "Modified" -MemberType Noteproperty -Value $localModifiedFormated
                        Write-ToLogFile -Message "Document loaded. Name: $($itemRelUrl); LastModified: $($localModifiedFormated)" -Path $LogFilePath -Level Info 
                        $Docs += $itemobj
                    }
                                          
                }
                else
                {
                    $listobj| Add-Member -Name "Type" -MemberType NoteProperty -Value "List"
                    
                }  
                
                $MossLists += $listobj
            }   
        }
        $webobj.Dispose()
    
    }
}

if($MossLists.Count -gt 0)
{
    Export-ToCsvFile -ListToExport $MossLists -CsvFileName "Lists"
    Write-ToLogFile -Message "Exported $($MossLists.Count) list(s) to $($CurrentDir)\Output\Lists.csv" -Path $LogFilePath -Level Info
}

if($Docs.Count -gt 0)
{
    Export-ToCsvFile -ListToExport $Docs -CsvFileName "MossDocuments"
    Write-ToLogFile -Message "Exported: $($Docs.Count) document(s) to $($CurrentDir)\Output\MossDocuments.csv" -Path $LogFilePath -Level Info
}

Write-Host
Write-Host "Done!" -ForegroundColor Green
Write-ToLogFile -Message "Done!" -Path $LogFilePath -Level Info

