#################FUNCTIONS####################
function Test-ProcHasAdmin
{return [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")}

function Get-DotNetBuildVersion
{return Get-ItemProperty "hklm:software\microsoft\net framework setup\ndp\v4\full" -ErrorAction:Silentlycontinue | Select -Expand 'Release' -ErrorAction:Silentlycontinue}

function Get-DotNetVersion
{
    param(
        [parameter(Mandatory=$true)]
        [string]$BuildNumber
    )
    $DotNetVersion = $null
    switch -Exact ($BuildNumber)
    {
        '378389' {$DotNetVersion='4.5';break}
        '378675' {$DotNetVersion='4.5.1';break}
        '378758' {$DotNetVersion='4.5.1';break}
        '379893' {$DotNetVersion='4.5.2';break}
        '393295' {$DotNetVersion='4.6';break}
        '393297' {$DotNetVersion='4.6';break}
        '394254' {$DotNetVersion='4.6.1';break}
        '394271' {$DotNetVersion='4.6.1';break}
        '394802' {$DotNetVersion='4.6.2';break}
        '394806' {$DotNetVersion='4.6.2';break}
        default {$DotNetVersion='N/A';break}
    }
    return $DotNetVersion
}

function Print-Result
{    
    return New-Object -TypeName PSCustomObject -Property @{
            DotNetVersion = Get-DotNetVersion $(Get-DotNetBuildVersion)
            PowerShellVersion = $PSVersionTable.PSVersion.Major
            SysmonStatus = (Get-Service -Name Sysmon).Status.ToString()
            NxlogStatus = (Get-Service -Name nxlog).Status.ToString()
    }|ConvertTo-Json
}

#################MAIN####################

If (!(Test-ProcHasAdmin))
{throw "You must be running as an administrator, please restart as administrator"}

$InstallScriptUrl = 'https://chocolatey.org/install.ps1'
$PowerShellMajorVersion = $PSVersionTable.PSVersion.Major
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force

#install Chocolatey
Write-Output "Installing Chockolatey..."
if($PowerShellMajorVersion -ge 3)
{
    Invoke-WebRequest $InstallScriptUrl -UseBasicParsing|Invoke-Expression
}
else
{
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($InstallScriptUrl))
}

#checking .NET version installed
Write-Output "Checking .NET Framework version..."
$DotNetBuildVersion = Get-DotNetBuildVersion
#if .NET >= 4.5.1 
if(($DotNetBuildVersion) -ge 378675)
  {
  Write-Output ".NET version (4.5.1) or greater is installed."
  if($PowerShellMajorVersion -ge 4)
  {
    $scriptpath = Split-Path $MyInvocation.MyCommand.Path    
    Write-Output "Installing and configuring sysmon"        
    & "$scriptpath\DSC-InstallSysmon.ps1"
    while((Get-Service -Name Sysmon).Status -ne "Running")
    {
        Write-Output "Waiting for sysmon service to start"
        Start-Sleep 2
    }        
    Write-Output "Sysmon service started"

    Write-Output "Installing and configuring nxlog"
    & "$scriptpath\DSC-InstallNxlog.ps1"
    while((Get-Service -Name nxlog).Status -ne "Running")
    {
        Write-Output "Waiting for Nxlog service to start"
        Start-Sleep 2
    }        
    Write-Output "Nxlog service started"

    Write-Output "Setting Vagent service"
    & "$scriptpath\DSC-SetVagent.ps1"
    while((Get-Service -Name vagent).Status -ne "Running")
    {
        Write-Output "Waiting for Vagent service to start"
        Start-Sleep 2
    }
            
    Write-Output "Vagent service started"
    if($PowerShellMajorVersion -ge 5)
    {
       Write-Output "Installing nuget provider"
       Install-PackageProvider -Name "Nuget" -Scope AllUsers -Confirm:$false -Force
    }
    Print-Result
    
  }
  #if PowerShell version < 4
  else
  {
    Write-Output "Upgrading PowerShell version..."
    Choco upgrade powershell
    
    Write-Output "Installing sysmon"
    Choco Install -y sysmon --ignore-checksums
    $sysmonPath = Join-Path $Env:ChocolateyInstall "lib\sysmon\tools"
    Write-Output "Configuring sysmon"
    if((Test-Path -Path $sysmonPath -PathType Container))
    {
    [string]$sysmonConfig = @'
<Sysmon schemaversion="3.10">
  <HashAlgorithms>*</HashAlgorithms>
</Sysmon>
'@
    $configPath = Join-Path $sysmonPath "sysmon.xml"
    $sysmonConfig|Out-File $configPath -Encoding utf8
    $sysmon = (Join-Path $sysmonPath "sysmon.exe")
    $argsuments = "-i $configPath -accepteula"
    $proc = Start-Process -FilePath $sysmon -ArgumentList $argsuments -WorkingDirectory $sysmonPath -PassThru -RedirectStandardError "$sysmonPath\error.log" -Wait
    if($proc.ExitCode -ne 0)
    {throw "Sysmon not configured - check $sysmonPath\error.log for details"}
    else
    {
        while((Get-Service -Name Sysmon).Status -ne "Running")
        {
            Write-Output "Waiting for sysmon service to start"
            Start-Sleep 2
        }        
        Write-Output "Sysmon service started"
    }
  }
  else
  {throw "Sysmon install path $sysmonPath not found - please re-run install"}
  Write-Output "Installing nxlog"
  Choco install -y nxlog
  $nxlogPath = "${Env:ProgramFiles(x86)}\nxlog"
  Write-Output "Configuring nxlog"
  if(Test-Path $nxlogPath)
  {
    [string]$nxlogConfig = @'
define ROOT C:\Program Files (x86)\nxlog

Moduledir %ROOT%\modules
CacheDir %ROOT%\data
Pidfile %ROOT%\data\nxlog.pid
SpoolDir %ROOT%\data
LogFile %ROOT%\data\nxlog.log

<Extension _syslog>
    Module      xm_syslog
</Extension>

<Extension json>
Module      xm_json
</Extension>

<Input in>
    Module      im_msvistalog
# For windows 2003 and earlier use the following:
#   Module      im_mseventlog
</Input>

<Output out>
    Module      om_tcp
    Host        localhost
    Port        20371
	Exec        $type="eventlog"; to_json();
    #Exec        to_syslog_snare();
</Output>

<Route 1>
    Path        in => out
</Route>

'@
   $configPath = Join-Path $nxlogPath "conf\nxlog.conf"
   $nxlogConfig|Out-File $configPath -Encoding default -Confirm:$false -Force
   $nxlogBin = Join-Path $nxlogPath "nxlog.exe"
   $svc= Start-Service -Name nxlog -PassThru   
   while($svc.Status -ne "Running")
   {
        Write-Output "Waiting for nxlog service to start"
        Start-Sleep 2
    }        
    Write-Output "Nxlog service started"  
  }
  else
  {throw "Nxlog install path $nxlogPath not found - please re-run install"}
  Print-Result    
  }
  
  }
#if .NET < 4.5.1 
else
  {
  Write-Output "The minimum .NET version (4.5.1) or greater is NOT installed, installing 4.6.1..."
  Choco Install -y dotnet4.6.1
  Write-Output "Installing sysmon"
  Choco Install -y sysmon --ignore-checksums
  $sysmonPath = Join-Path $Env:ChocolateyInstall "lib\sysmon\tools"
  Write-Output "Configuring sysmon"
  if((Test-Path -Path $sysmonPath -PathType Container))
  {
    [string]$sysmonConfig = @'
<Sysmon schemaversion="3.10">
  <HashAlgorithms>*</HashAlgorithms>
</Sysmon>
'@
    $configPath = Join-Path $sysmonPath "sysmon.xml"
    $sysmonConfig|Out-File $configPath -Encoding utf8
    $sysmon = (Join-Path $sysmonPath "sysmon.exe")
    $argsuments = "-i $configPath -accepteula"
    $proc = Start-Process -FilePath $sysmon -ArgumentList $argsuments -WorkingDirectory $sysmonPath -PassThru -RedirectStandardError "$sysmonPath\error.log" -Wait
    if($proc.ExitCode -ne 0)
    {throw "Sysmon not configured - check $sysmonPath\error.log for details"}
    else
    {
        while((Get-Service -Name Sysmon).Status -ne "Running")
        {
            Write-Output "Waiting for sysmon service to start"
            Start-Sleep 2
        }        
        Write-Output "Sysmon service started"
    }
  }
  else
  {throw "Sysmon install path $sysmonPath not found - please re-run install"}
  Write-Output "Installing nxlog"
  Choco install -y nxlog
  $nxlogPath = "${Env:ProgramFiles(x86)}\nxlog"
  Write-Output "Configuring nxlog"
  if(Test-Path $nxlogPath)
  {
    [string]$nxlogConfig = @'
define ROOT C:\Program Files (x86)\nxlog

Moduledir %ROOT%\modules
CacheDir %ROOT%\data
Pidfile %ROOT%\data\nxlog.pid
SpoolDir %ROOT%\data
LogFile %ROOT%\data\nxlog.log

<Extension _syslog>
    Module      xm_syslog
</Extension>

<Extension json>
Module      xm_json
</Extension>

<Input in>
    Module      im_msvistalog
# For windows 2003 and earlier use the following:
#   Module      im_mseventlog
</Input>

<Output out>
    Module      om_tcp
    Host        localhost
    Port        20371
	Exec        $type="eventlog"; to_json();
    #Exec        to_syslog_snare();
</Output>

<Route 1>
    Path        in => out
</Route>

'@
   $configPath = Join-Path $nxlogPath "conf\nxlog.conf"
   $nxlogConfig|Out-File $configPath -Encoding default -Confirm:$false -Force
   $nxlogBin = Join-Path $nxlogPath "nxlog.exe"
   $svc= Start-Service -Name nxlog -PassThru   
   while($svc.Status -ne "Running")
   {
        Write-Output "Waiting for nxlog service to start"
        Start-Sleep 2
    }        
    Write-Output "Nxlog service started"  
  }
  else
  {throw "Nxlog install path $nxlogPath not found - please re-run install"}
  Print-Result
  Restart-Computer        
}



