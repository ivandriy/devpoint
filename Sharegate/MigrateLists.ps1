param(
    [string]$SourceUrl,
    [string]$DestinationUrl,
    [string]$SourceUserName,
    [string]$SourcePassword,
    [string]$DestinationUserName,
    [string]$DestinationPassword,
    [string]$FromDate,
    [string]$ToDate

)

Import-Module Sharegate

###############--FUNCTIONS--#################################################
function MigrateLists([string]$SourceUrl,[string]$SourceUserName,[string]$SourcePassword, [string]$DestinationUrl,[string]$DestinationUserName,[string]$DestinationPassword,[string]$From,[string]$To)
{
   
    Write-Host "=============================================================="
    $StartTime=Get-Date
    Write-Host "Script started at $($StartTime)"
    Write-Host "Start migrating lists from $($SourceUrl) to $($DestinationUrl)"
    $srcSite=Connect-SPSite -SiteUrl $SourceUrl -User $SourceUserName -Password $SourcePassword
    $dstsite=Connect-SPSite -SiteUrl $DestinationUrl -User $DestinationUserName -Password $DestinationPassword
    $propertyTemplate = New-PropertyTemplate -AuthorsAndTimestamps -VersionHistory -Permissions -NoLinkCorrection -VersionLimit 10 -CheckInAs Publish -ContentApproval SameAsCurrent -From $From -To $To
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Get-List -Site $srcSite |Where-Object {(-not ($systemlibs -Contains $_.Title))}|ForEach-Parallel -Site $dstsite -PropertyTemplate $propertyTemplate -MaxThreads 10
    $sw.Stop()
    Write-Host "Total execution time: $($sw.Elapsed.Hours) hours $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec"
    $FinishDate=Get-Date
    Write-Host "Script finished at $($FinishDate)"
    Write-Host "=============================================================="
}

function Connect-SPSite([string]$SiteUrl,[string]$User,[string]$Password)
{
    if(($User -ne "") -and ($Password -ne ""))
    {
        $secpwd = ConvertTo-SecureString $Password -AsPlainText -Force
        try
        {
            Connect-Site -Url $SiteUrl -UserName $User -Password $secpwd
        }
        catch
        {
            Write-Host "Error connecting to $SiteUrl - $Error[0].Exception"
        } 
    }
    else
    {
        try
        {
            Connect-Site -Url $SiteUrl
        }
        catch
        {
            Write-Host "Error connecting to $SiteUrl - $Error[0].Exception"
        }    
    }
}

function ForEach-Parallel {
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [Sharegate.Automation.Entities.List]$List,
        [Parameter(Mandatory=$true)]
        [Sharegate.Automation.Entities.Site]$Site,
        [Sharegate.Automation.Entities.PropertyTemplate]$PropertyTemplate,
        [Parameter(Mandatory=$false)]
        [int]$MaxThreads=5
    )
    BEGIN {
        $iss = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
        $pool = [Runspacefactory]::CreateRunspacePool(1, $maxthreads, $iss, $host)
        $pool.open()
        $threads = @()
        $code={
            param($List,$Site,$PropertyTemplate)
            if($List.Title -match "Shared Documents")
            {
                $dstList = Get-List -Name "Documents" -Site $Site
            }
            else
            {
                $dstList = Get-List -Name $List.Title -Site $Site
            }       
            if ($dstList -eq $null)
            {
              throw "List [$($List.Title)] not found on destination site -$($Site.Address)"
                
            }
            Write-Host "Start copying list [$($List.Title)] to $($Site.Address)"
            $result = Copy-Content -SourceList $List -DestinationList $dstList -Template $PropertyTemplate
            if($result.Errors -eq 0)
            {
                Write-Host "Finished copying list [$($List.Title)] to $($Site.Address): copied $($result.ItemsCopied) item(s)" 
                $TimeStamp = Get-Date -Format yyyyMd_HH-mm-ss
                $ReportFile = "C:\CopyReport_"+$List.Title+"_"+ $TimeStamp+".xlsx"
                Export-Report $result -Path $ReportFile |Out-Null
                Write-Host "Copy report saved at: $($ReportFile)"
            }
            elseif($result.Errors -gt 0)
            {
                Write-Host -ForegroundColor Yellow "List [$($List.Title)] copied with $($result.Errors) error(s)." 
            }                    
            
        }
    }
    PROCESS {
        $powershell = [powershell]::Create().addscript($code).addargument($List).addargument($Site).AddArgument($PropertyTemplate)
        $powershell.runspacepool=$pool
        $threads+= @{
            instance = $powershell
            handle = $powershell.begininvoke()
        }
    }
    END {
        $notdone = $true
        while ($notdone) {
            $notdone = $false
            for ($i=0; $i -lt $threads.count; $i++) {
                $thread = $threads[$i]
                if ($thread) {
                    if ($thread.handle.iscompleted) {
                        $thread.instance.endinvoke($thread.handle)
                        $thread.instance.dispose()
                        $threads[$i] = $null
                    }
                    else {
                        $notdone = $true
                    }
                }
            }
        }
    }
}

###############--FUNCTIONS--#################################################

###############--MAIN--######################################################

#Array with system list names
$systemlibs =@("Converted Forms", "Customized Reports", "Documents", "Form Templates",  
                              "Images", "List Template Gallery", "Master Page Gallery", "Pages",  
                               "Reporting Templates", "Site Assets", "Site Collection Documents", 
                               "Site Collection Images", "Site Pages", "Solution Gallery",  
                               "Style Library", "Theme Gallery", "Web Part Gallery", "wfpub","User Information List")

<#$SourceUserName=""
$SourcePassword=""
$FromDate = "2015-07-20"
$ToDate = "2015-07-23"
$DestinationUserName="dev.elance.andrey@miamiedu.onmicrosoft.com"
$DestinationPassword="nomad_is_1593*"
$SourceUrl="http://lst-app"
$DestinationUrl="https://miamiedu.sharepoint.com/sites/devandrey2"#>
cls
MigrateLists -SourceUrl $SourceUrl -DestinationUrl $DestinationUrl -SourceUserName $SourceUserName -SourcePassword $SourcePassword -DestinationUserName $DestinationUserName -DestinationPassword $DestinationPassword -From $FromDate -To $ToDate


