param
(
    [parameter(Mandatory=$true)]
    [string]$MossSiteUrl
)

if ($PSVersionTable.PSVersion -gt [Version]"2.0") {
  powershell -Version 2 -File $MyInvocation.MyCommand.Definition $MossSiteUrl
  exit
}


Write-Host "Load MOSS PowerShell assembly" -ForegroundColor Black -BackgroundColor Yellow
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
Write-Host "MOSS PowerShell assembly loaded successfully" -ForegroundColor Black -BackgroundColor Green

$systemlibs =@("Converted Forms", "Customized Reports", "Form Templates",  
                              "Images", "List Template Gallery", "Master Page Gallery", "Pages",  
                               "Reporting Templates", "Site Assets", "Site Collection Documents", 
                               "Site Collection Images", "Site Pages", "Solution Gallery",  
                               "Style Library", "Theme Gallery", "Web Part Gallery", "wfpub","User Information List","Workflows","Workflow History","Tasks")

$MossLists = @()
$site = New-Object Microsoft.SharePoint.SPSite($MossSiteUrl)

Write-Host
Write-Host "Starting export lists from site: $MossSiteUrl"
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
                    $CurrentDir = Split-Path -parent $MyInvocation.MyCommand.Path
                    $SaveDir = $CurrentDir+"\MOSS_Libraries"
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
                     Write-Host "Library [$list] exported to: $OutputFilePath"
                     Write-Host                      
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


#For Output file generation
$SaveDir = Split-Path -parent $MyInvocation.MyCommand.Path
$OutputFileName = "MOSS_"+$site.RootWeb.Title + "_Lists.csv"
$OutputFilePath = $SaveDir+"\"+$OutputFileName
#delete the file, If already exist!
if (Test-Path $OutputFilePath)
 {
    Remove-Item $OutputFilePath
 }

$MossLists|Export-Csv $OutputFilePath -NoTypeInformation
Write-Host "Lists report saved to: $OutputFilePath"
Write-Host

