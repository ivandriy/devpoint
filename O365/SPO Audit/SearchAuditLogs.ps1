param(
    [string]$UserName,
    [string]$Password,
    [string]$StartDate,
    [string]$EndDate,        
    [string]$ObjectId
)

Write-Host
Write-Host "Current script version - #1" -ForegroundColor Magenta -BackgroundColor Black
$StartTime=Get-Date
Write-Host
Write-Host "Script started at $($StartTime)" -ForegroundColor Yellow -BackgroundColor Black
Write-Host
$sw = [Diagnostics.Stopwatch]::StartNew()

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
    [string]$SessionId = [GUID]::NewGuid()
    Write-Host
    Write-Host "Loading audit data from SPO..."
    if(!$ObjectId)
    {
        $results = Search-UnifiedAuditLog -StartDate $($Start.ToShortDateString()) -EndDate $($End.ToShortDateString()) -RecordType SharePointFileOperation -Operations FileAccessed -SessionId $SessionId -SessionCommand ReturnNextPreviewPage -ResultSize 5000
    }
    else
    {
        $results = Search-UnifiedAuditLog -StartDate $($Start.ToShortDateString()) -EndDate $($End.ToShortDateString()) -ObjectIds $ObjectId -RecordType SharePointFileOperation -Operations FileAccessed -SessionId $SessionId -SessionCommand ReturnNextPreviewPage -ResultSize 5000
    }
}
catch
{
    Write-Host "Caught an exception" -ForegroundColor Red
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
    $CurrentDir = Split-Path -parent $script:MyInvocation.MyCommand.Path
    $FormattedDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $OutFileName = 'AuditResults_'+$FormattedDate+'.csv'
    $OutFilePath = Join-Path $CurrentDir $OutFileName
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
