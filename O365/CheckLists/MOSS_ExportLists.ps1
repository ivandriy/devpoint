﻿param
(
    [parameter(Mandatory=$true)]
    [string]$MossSiteUrl,

    [switch]
    $AllSubWebs
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


if ($PSVersionTable.PSVersion -gt [Version]"2.0") {
  powershell -Version 2 -File $MyInvocation.MyCommand.Definition $MossSiteUrl
  exit
}


Write-Host "Loading MOSS PowerShell assembly..."
try
{
    [void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")    
}
catch
{
    Write-Host "Caught an exception while loading MOSS assenbly:" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    return    
}

$systemlibs =@("Converted Forms", "Customized Reports", "Form Templates",  
                              "Images", "List Template Gallery", "Master Page Gallery", "Pages",  
                               "Reporting Templates", "Site Assets", "Site Collection Documents", 
                               "Site Collection Images", "Site Pages", "Solution Gallery",  
                               "Style Library", "Theme Gallery", "Web Part Gallery", "wfpub","User Information List","Workflows","Workflow History","Tasks")

$MossLists = @()
$CurrentDir = Split-Path -parent $MyInvocation.MyCommand.Path
$TargetDir = $CurrentDir+"\Output"

$site = New-Object Microsoft.SharePoint.SPSite($MossSiteUrl)

Write-Host
Write-Host "Starting export lists from site: $MossSiteUrl"
if($AllSubWebs)
{
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
                $listobj| Add-Member -Name "Url" -MemberType NoteProperty -Value $listurl
                $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate
                $listobj| Add-Member -Name "ItemCount" -MemberType NoteProperty -Value $list.ItemCount

                if($list.BaseTemplate -eq "DocumentLibrary")
                {
                    $Docs = @()
                    $listobj| Add-Member -Name "Type" -MemberType NoteProperty -Value "Library"
                    
                    foreach($item in $list.Items)
                    {
                        $itemobj=New-Object -TypeName PSObject
                        $itemobj|Add-Member -Name "Name" -MemberType Noteproperty -Value $item["Name"]                        
                        $itemobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $item["ServerUrl"]
                        $itemobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $item["ows_EncodedAbsUrl"]                        
                        $itemobj|Add-Member -Name "Modified" -MemberType Noteproperty -Value $item["Modified"]                        
                        $Docs += $itemobj
                    }
                    
                    if(!(Test-Path $TargetDir))
                    {
                        New-Item -ItemType Directory -Force -Path $TargetDir|Out-Null
                    }
                    $SaveDir = $TargetDir+"\MOSS_Libraries"
                    if(!(Test-Path $SaveDir))
                    {
                        New-Item -ItemType Directory -Force -Path $SaveDir|Out-Null
                    }
                    
                    $OutputFileName = $web.Title +"_"+$list.Title+".csv"
                    $OutputFilePath = $SaveDir+"\"+$OutputFileName
                    $listobj| Add-Member -Name "ItemsFilePath" -MemberType NoteProperty -Value $OutputFilePath
                    if (Test-Path $OutputFilePath)
                     {
                        Remove-Item $OutputFilePath
                     }
                     $Docs|Export-Csv $OutputFilePath -NoTypeInformation                      
                }
                else
                {
                    $listobj| Add-Member -Name "Type" -MemberType NoteProperty -Value "List"
                    $listobj| Add-Member -Name "ItemsFilePath" -MemberType NoteProperty -Value ""
                    
                }  
                
                $MossLists += $listobj
            }   
        }
        $webobj.Dispose()
    
    }
}
else
{
        $web = $site.RootWeb
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
                $listobj| Add-Member -Name "Url" -MemberType NoteProperty -Value $listurl
                $listobj| Add-Member -Name "LastModified" -MemberType NoteProperty -Value $list.LastItemModifiedDate
                $listobj| Add-Member -Name "ItemCount" -MemberType NoteProperty -Value $list.ItemCount

                if($list.BaseTemplate -eq "DocumentLibrary")
                {
                    $Docs = @()
                    $listobj| Add-Member -Name "Type" -MemberType NoteProperty -Value "Library"
                    
                    foreach($item in $list.Items)
                    {
                        $itemobj=New-Object -TypeName PSObject
                        $itemobj|Add-Member -Name "Name" -MemberType Noteproperty -Value $item["Name"]                        
                        $itemobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $item["ServerUrl"]
                        $itemobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $item["ows_EncodedAbsUrl"]                        
                        $itemobj|Add-Member -Name "Modified" -MemberType Noteproperty -Value $item["Modified"]                        
                        $Docs += $itemobj
                    }
                    
                    if(!(Test-Path $TargetDir))
                    {
                        New-Item -ItemType Directory -Force -Path $TargetDir|Out-Null
                    }
                    $SaveDir = $TargetDir+"\MOSS_Libraries"
                    if(!(Test-Path $SaveDir))
                    {
                        New-Item -ItemType Directory -Force -Path $SaveDir|Out-Null
                    }
                    
                    $OutputFileName = $web.Title +"_"+$list.Title+".csv"
                    $OutputFilePath = $SaveDir+"\"+$OutputFileName
                    $listobj| Add-Member -Name "ItemsFilePath" -MemberType NoteProperty -Value $OutputFilePath
                    if (Test-Path $OutputFilePath)
                     {
                        Remove-Item $OutputFilePath
                     }
                     $Docs|Export-Csv $OutputFilePath -NoTypeInformation                      
                }
                else
                {
                    $listobj| Add-Member -Name "Type" -MemberType NoteProperty -Value "List"
                    $listobj| Add-Member -Name "ItemsFilePath" -MemberType NoteProperty -Value ""
                    
                }  
                
                $MossLists += $listobj
            }   
        }
        $webobj.Dispose()
     
}

if($MossLists.Count -gt 0)
{
    Export-ToCsvFile -ListToExport $MossLists -CsvFileName "Lists"
    Write-Host
    Write-Host "Exported: $($MossLists.Count) list(s)"
}

Write-Host
Write-Host "Done!" -ForegroundColor Green

