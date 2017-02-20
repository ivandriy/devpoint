param(
    [string]$UserName,
    [string]$Password,
    [string]$StartDate,
    [string]$EndDate,
    [string]$FilesLocation
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
        $SiteUrl = $SiteUrl.TrimEnd('/')
        $SiteUrl -match "https?://.*?/"|Out-Null
        $RootUrl = $Matches[0]
        $RootUrl = $RootUrl.TrimEnd('/')
        $fileUrl = $RootUrl+$file.ServerRelativeUrl
                
        $fileobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $file.ServerRelativeUrl
        $fileobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $fileUrl
        
        $item = $file.ListItemAllFields
        $Context.Load($item)
        $Context.ExecuteQuery()
        $localModified = $item["Modified"]

        $fileobj|Add-Member -Name "Modified" -MemberType Noteproperty -Value $localModified        
        $files +=$fileobj        
    }
    return $files
}

function Get-SPOContext
{
    param(
    [string]$siteUrl,
    [string]$UserName,
    [securestring]$Password
    )

    $context = New-Object Microsoft.SharePoint.Client.ClientContext($siteUrl)     
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
        Write-Host "Not able to authenticate to O365 site: $siteUrl" -ForegroundColor Red
        Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
        return 
    }
    return $context
}
#endregion


Write-Host
Write-Host "Current script version - #2" -ForegroundColor Magenta -BackgroundColor Black
$StartTime=Get-Date
Write-Host
Write-Host "Script started at $($StartTime)" -ForegroundColor Yellow -BackgroundColor Black
Write-Host
$sw = [Diagnostics.Stopwatch]::StartNew()

#Variables init
$CurrentDir = Split-Path -parent $MyInvocation.MyCommand.Path
$DllsDir = Join-Path $CurrentDir 'DLL'
$FormattedDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$OutFileName = 'AuditResults_'+$FormattedDate+'.csv'
$OutFilePath = Join-Path $CurrentDir $OutFileName

try
{
    Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.dll" 
    Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.Runtime.dll"    
}
catch
{
    Write-Host "Caught an exception when load client dll's" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    return    
}

if(!$UserName)
{
    $UserName= Read-Host "Please enter SPO user name "
}
if(!$Password)
{
    $SecurePassword = Read-host "Please provide password for $UserName" -AsSecureString
}
else
{
    $SecurePassword = $Password|ConvertTo-SecureString -AsPlainText -Force
}
if((!$StartDate) -or (!$EndDate))
{
    [datetime]$Start = Read-Host "Please enter StartDate (M/d/yyyy) "
    [datetime]$End = Read-Host "Please enter EndDate (M/d/yyyy) "
}
else
{
    [datetime]$Start = [datetime]::Parse($StartDate)
    [datetime]$End = [datetime]::Parse($EndDate)
}

[uri]$FilesUrl = $FilesLocation
$RelativePath = $FilesUrl.AbsolutePath
$AbsolutePath = $FilesUrl.AbsoluteUri
$RootSite = $AbsolutePath.Remove($AbsolutePath.Length - $RelativePath.Length)
$SiteUrl = $RootSite + $FilesUrl.Segments[0] + $FilesUrl.Segments[1]+ $FilesUrl.Segments[2]

$FolderFiles = @()
$Context = Get-SPOContext -siteUrl $SiteUrl -UserName $UserName -Password $SecurePassword
[Microsoft.SharePoint.Client.Web]$Web = $Context.Web
$Context.Load($Web)
$Context.ExecuteQuery()

[Microsoft.SharePoint.Client.Folder]$Folder = $Context.Web.GetFolderByServerRelativeUrl($RelativePath)
$Context.Load($Folder)
$Context.Load($Folder.Folders)
$Context.ExecuteQuery()
$FolderFiles = Recurse -Folder $Folder -Context $Context

$results = @()
$Creds = New-Object -TypeName PSCredential -ArgumentList $Username,$SecurePassword
$Sessions = Get-PSSession
if($null -ne ($Sessions))
{
    foreach($s in $Sessions)
    {Remove-PSSession -Session $s}
}

try
{
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $creds -Authentication Basic -AllowRedirection
    Import-PSSession $Session -AllowClobber
    Write-Host
    Write-Host "Loading audit data from SPO..."

    foreach($file in $FolderFiles)
    {
        $results += Search-UnifiedAuditLog -StartDate $($Start.ToShortDateString()) -EndDate $($End.ToShortDateString()) -ObjectIds "`"$($file.Url)`"" -Operations FileAccessed -SessionId $([GUID]::NewGuid().ToString()) -SessionCommand ReturnNextPreviewPage -ResultSize 5000    
    }    
}
catch
{
    Write-Host "Caught an exception when load audit logs" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    return    
}

if($null -ne $results)
{
    Write-Host
    Write-Host "Parsing $($results.Count) audit records..."
    $AuditData = @()
    $results|ForEach-Object{
        $obj = New-Object psobject
        $obj|Add-Member -MemberType NoteProperty -Name Data -Value $_.AuditData
        $AuditData += $obj
    }
    $AuditData|ForEach-Object{
        ConvertFrom-Json -InputObject $_.Data|Export-Csv $OutFilePath -Append -NoTypeInformation -Force
    }
    Write-Host
    Write-Host "Report saved to: $OutFilePath"
    $sw.Stop()
    Write-Host
    Write-Host "Total execution time: $($sw.Elapsed.Hours) hours $($sw.Elapsed.Minutes) min $($sw.Elapsed.Seconds) sec" -ForegroundColor Yellow -BackgroundColor Black
    $FinishDate=Get-Date
    Write-Host "Script finished at $($FinishDate)" -ForegroundColor Yellow -BackgroundColor Black
    Write-Host
    Write-Host "Done!" -ForegroundColor Green
}
else
{
    Write-Host
    Write-Warning "No audit logs returned - exit.."
}
