#################FUNCTIONS####################
#region Functions
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

Function Console-Prompt 
{
  param(
      [string[]]$choiceList,
      [string]$Caption = "Please make a selection",
      [string]$Message = "Choices are presented below",
      [int]$default = 0
  )
    $choicedesc = New-Object System.Collections.ObjectModel.Collection[System.Management.Automation.Host.ChoiceDescription] 
    $choiceList | foreach { 
    $comps = $_ -split '=' 
    $choicedesc.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList $comps[0],$comps[1]))} 
    $Host.ui.PromptForChoice($caption, $message, $choicedesc, $default) 
}
#endregion

#region DesiredStateConfiguration
Configuration SysmonDSC {
    param
    (
        [string[]]$NodeName = 'localhost'
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Node $NodeName
    {
        Script DownloadSysmon {
            GetScript = {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result  = $(Test-Path (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath sysmon.exe));
                }
            }
            SetScript = {
                try {
                    # https://msdn.microsoft.com/en-us/library/system.io.path.gettempfilename%28v=vs.110%29.aspx
                    $tmpfile = [System.IO.Path]::GetTempFileName()
                    $null = Invoke-WebRequest -Uri 'https://live.sysinternals.com/Sysmon.exe' `
                                      -OutFile $tmpfile -ErrorAction Stop
                    Write-Verbose -Message 'Sucessfully downloaded Sysmon.exe'
                    Unblock-File -Path $tmpfile -ErrorAction Stop
                    $exefile = Join-Path -Path (Split-Path -Path $tmpfile -Parent) -ChildPath 'a.exe'
                    if (Test-Path $exefile) {
                        Remove-Item -Path $exefile -Force -ErrorAction Stop
                    }
                    $tmpfile | Rename-Item -NewName 'a.exe' -Force -ErrorAction Stop

                } catch {
                    Write-Verbose -Message "Something went wrong $($_.Exception.Message)"
                }
            }
            TestScript = { 
                $s = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath a.exe -ErrorAction SilentlyContinue
                if (-not(Test-Path -Path $s -PathType Leaf)) {
                    Write-Verbose -Message "Cannot find sysmon.exe in temp"
                    return $false
                }
                if(
                    (Get-FileHash -Path $s -Algorithm SHA256).Hash -eq 'E6BA49275B3EC33232D91741CAEF1B99A58460EEB4BC44F26086FE076FAD333A' -and
                    (Get-AuthenticodeSignature -FilePath $s).Status.value__ -eq 0 # Valid
                
                ) {
                    Write-Verbose -Message 'Successfully found a valid signed sysmon.exe'
                    return $true
                } else {
                    Write-Verbose -Message 'A valid signed sysmon.exe was not found'
                    return $false
                }
            }
        }
        Registry SysmonEULA {
            Key = 'HKEY_USERS\S-1-5-18\Software\Sysinternals\System Monitor'
            ValueName = 'EulaAccepted';
            ValueType = 'DWORD'
            ValueData = '1'
            Ensure = 'Present'
            Force = $true;

        }
        Script InstallSysmon {
            GetScript = {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result  = $(if (@(Get-Service -Name sysmon,sysmondrv).Count -eq 2) { $true } else { $false });
                }
            }
            SetScript = {
                $sysmonbin = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath a.exe
                $s = Copy-Item -Path $sysmonbin -Destination "$($env:systemroot)\system32\sysmon.exe" -PassThru -Force
                try {
                    $null = Start-Process -FilePath $s -ArgumentList @('-i','-accepteula') -PassThru -NoNewWindow -ErrorAction Stop | Wait-Process
                    Write-Verbose -Message 'Successfully installed sysmon'
                } catch {
                    throw $_
                }
            }
            TestScript = { 
                if(
                    Get-WinEvent -ListLog * | Where LogName -eq 'Microsoft-Windows-Sysmon/Operational'
                ) {
                    Write-Verbose -Message "Sysmon is installed"
                    return $true
                } else {
                    Write-Verbose -Message "Sysmon isn't installed"
                    return $false
                }
            }
           DependsOn = '[Script]DownloadSysmon','[Registry]SysmonEULA'
        }
        Script ConfigureSysmon {
            GetScript = {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result  = $();
                }
            }
            SetScript = {
                $s = "$($env:systemroot)\system32\sysmon.exe"
                $null = Start-Process -FilePath  $s -ArgumentList @('-c','--') -PassThru -NoNewWindow | Wait-Process
                $null = Start-Process -FilePath  $s -ArgumentList @('-c','C:\windows\temp\polSysmon.xml') -PassThru -NoNewWindow | Wait-Process
            }
            TestScript = { 
                Function Convert-SysmonConfigToXMLBlob {
                [CmdletBinding()]
                Param()
                     try {
                        $t = [system.io.path]::GetTempFileName()
                        
                        $null = Start-Process -FilePath "$($env:systemroot)\system32\sysmon.exe" -ArgumentList @('-c') `
                                -NoNewWindow -PassThru -RedirectStandardOutput $t -ErrorAction Stop -Wait
                     } catch {
                        Write-Warning "Dumping sysmon config went wrong!"
                        break
                     }
  
                    if($config = Get-Content $t) {
                        '<Sysmon schemaversion="2.0">'

                        $Hashing = (([regex]'\s-\sHashingAlgorithms:\s+(?<Hash>.*)').Match(@($config)[3]) | Select -expand Groups)[-1].Value
                        '  <HashAlgorithms>{0}</HashAlgorithms>' -f $Hashing
 

                        if (@($config)[7] -match '^Rule\sconfiguration\s\(version\s\d{1}\.\d{1,2}\):$') {
                            ' <EventFiltering>'
                            $prop = @()
                            (($config)[-1..-(($config).Length-8)]) | ForEach-Object {
                                if ($_ -notmatch '\s-\s.*') {
                                    $prop += $_
                                } else {
                                    $node,$attribute = ([regex]'\s-\s(?<NodeName>\w+)\s+onm(n)?atch:\s(?<attribute>.*clude)').Matches($_).Groups |
                                    Select -Last 2| Select -expand Value
                                    if ($prop) {
                                        '  <{0} onmatch="{1}">' -f $node,$attribute
                                        $prop | ForEach-Object {
                                            $ChildNode,$filter,$value = ([regex]"\s+(?<ChildNode>\w+)\s+filter:\s(?<filter>\w+)\s+value:\s'(?<Value>.*)'").Matches($_).Groups |
                                            Select -Last 3 | Select -Expand Value
                                            '   <{0} condition="{1}">{2}</{0}>' -f $ChildNode,$filter,$value
                                        }
                                        '  </{0}>' -f $node 
                                    } else {
                                        '  <{0} onmatch="{1}"/>' -f $node,$attribute
                                    }
                                    $prop = @()
                                }
                            }
                            ' </EventFiltering>'
                        }
                        '</Sysmon>'
                    } else {
                        Write-Warning "Cannot find output in $t"
                    }
                } #endof function

                if(
                Compare-Object -ReferenceObject  ([xml](Convert-SysmonConfigToXMLBlob)).InnerXML `
                               -DifferenceObject ([xml](Get-Content -Path C:\windows\temp\invpolSysmon.xml -Encoding UTF8 )).InnerXml

                ) {
                    Write-Verbose -Message "Sysmon needs to be configured"
                    return $false
                } else {
                    Write-Verbose -Message "Sysmon is already configured"
                    return $true
                }
            }
           DependsOn = '[Script]InstallSysmon','[Registry]SysmonEULA','[File]SysmonXMLPol','[File]InvSysmonXMLPol'
        }        
        File  SysmonXMLPol {
            DestinationPath = 'C:\windows\temp\polSysmon.xml'
            Ensure = 'Present';
            Force = $true
            Contents = @'
<Sysmon schemaversion="3.10">
  <HashAlgorithms>*</HashAlgorithms>
</Sysmon>
'@
        }
        File  InvSysmonXMLPol {
            DestinationPath = 'C:\windows\temp\invpolSysmon.xml'
            Ensure = 'Present';
            Force = $true
            Contents = @'
<Sysmon schemaversion="3.10">
  <HashAlgorithms>*</HashAlgorithms>
</Sysmon>
'@
        }

    }
}

Configuration NxLogDSC {
    param
    (
        [string[]]$NodeName = 'localhost'
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Node $NodeName
    {
        Script DownloadNxLog{
            GetScript = {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result  = $(Test-Path (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'nxlog-ce.msi'));
                }
            }
            SetScript = {
                try {
                    $tmpfile = [System.IO.Path]::GetTempFileName()
                    $null = Invoke-WebRequest -Uri 'https://nxlog.co/system/files/products/files/1/nxlog-ce-2.9.1716.msi' `
                                      -OutFile $tmpfile -ErrorAction Stop
                    Write-Verbose -Message 'Sucessfully downloaded Nxlog-ce.msi'
                    Unblock-File -Path $tmpfile -ErrorAction Stop
                    $msifile = Join-Path -Path (Split-Path -Path $tmpfile -Parent) -ChildPath 'nxlog-ce.msi'
                    if (Test-Path $msifile) {
                        Remove-Item -Path $msifile -Force -ErrorAction Stop
                    }
                    $tmpfile | Rename-Item -NewName 'nxlog-ce.msi' -Force -ErrorAction Stop

                } catch {
                    Write-Verbose -Message "Something went wrong $($_.Exception.Message)"
                }
            }
           TestScript = {                
                $s = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'nxlog-ce.msi' -ErrorAction SilentlyContinue
                Write-Verbose -Message "Checking if $s in in place"
                if (-not(Test-Path -Path $s -PathType Leaf)) {
                    Write-Verbose -Message "Cannot find nxlog-ce.msi in temp"
                    return $false
                }
                else
                {
                    Write-Verbose -Message 'Successfully found nxlog-ce.msi'
                    return $true
                } 
            }
        }

        Script InstallNxlog {
            GetScript = {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript                                        
                    Result  = $(Test-Path (Join-Path -Path (${Env:ProgramFiles(x86)}) -ChildPath 'nxlog\nxlog.exe') -PathType Leaf);                    
                }
            }
            SetScript = {
                $msipath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'nxlog-ce.msi'
                $msiparms = "/l*  $($env:TEMP)\nxlog-ce-install.log /qn"
                try
                {
                  $proc=Start-Process -FilePath "$($env:SystemRoot)\System32\msiexec.exe" -ArgumentList "/i $msipath $msiparms" -NoNewWindow -PassThru -Wait -RedirectStandardError "$($env:TEMP)\nxlog-install-error.log" -ErrorAction Stop 
                  Write-Verbose -Message 'Successfully installed nxlog' 
                }
                catch
                {
                    throw $_
                }                
            }
            TestScript = { 
                if(
                    (Test-Path (Join-Path -Path (${Env:ProgramFiles(x86)}) -ChildPath 'nxlog\nxlog.exe') -PathType Leaf) 
                ) {
                    Write-Verbose -Message "Nxlog is installed"
                    return $true
                } else {
                    Write-Verbose -Message "Nxlog isn't installed"
                    return $false
                }
            }
           DependsOn = '[Script]DownloadNxlog'
        }
        
        Script ConfigureNxlog {
            GetScript = {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result  = $();
                }
            }

            SetScript = {
                $nxlogPath = "${Env:ProgramFiles(x86)}\nxlog"
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
                if((Get-Service -Name nxlog -ErrorAction: SilentlyContinue).Status -eq 'Running')
                {
                    Stop-Service -Name nxlog -Force 
                } 
                $nxlogConfig|Out-File $configPath -Encoding default -Confirm:$false -Force
                try
                {
                    $svc= Start-Service -Name nxlog -PassThru -ErrorAction Stop
                    while($svc.Status -ne "Running")
                    {
                        Write-Output "Waiting for nxlog service to start"
                        Start-Sleep 2
                    }        
                    Write-Output "Nxlog service started"
                }
                catch
                {throw $_}                  
            }
            TestScript = {
                $nxlogPath = "${Env:ProgramFiles(x86)}\nxlog"
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
                if(Test-Path $configPath -PathType Leaf -ErrorAction: SilentlyContinue)
                {
                    $tmpfile = [System.IO.Path]::GetTempFileName()                    
                    $nxlogConfig.Replace("`r`n","`n") |Out-File $tmpfile -Encoding default -Confirm:$false -Force                    
                    if((Get-FileHash -Path $configPath) -ne (Get-FileHash -Path $tmpfile))
                    {
                        Write-Verbose -Message "Nxlog config need to be updated"
                        return $false
                    }
                    elseif((Get-Service -Name nxlog -ErrorAction: SilentlyContinue).Status -ne 'Running')
                    {
                        Write-Verbose -Message "Nxlog service not started"
                        return $fals
                    }
                    else
                    {
                        Write-Verbose -Message "Nxlog service is started and configured"
                        return $true 
                    }
                }
                else
                {
                    Write-Verbose -Message "Nxlog config not found"
                    return $false
                }                
            }
            DependsOn = '[Script]DownloadNxlog','[Script]InstallNxlog'
        }

    }
}

Configuration VAgentDSC {
    param
    (
        [string[]]$NodeName = 'localhost'
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Node $NodeName
    {

        Service VAgentService
        {
            Name        = "Vagent"            
            State       = "Running"
        } 
    }

}
 
#endregion

################GLOBALS##################
$ChocoScriptUrl = 'https://chocolatey.org/install.ps1'
$PowerShellMajorVersion = $PSVersionTable.PSVersion.Major
$DotNetBuildVersion = Get-DotNetBuildVersion
$DscConfigRoot = Join-Path -Path $env:SystemDrive -ChildPath "DSC"
[string]$sysmonConfig = @'
<Sysmon schemaversion="3.10">
  <HashAlgorithms>*</HashAlgorithms>
</Sysmon>
'@
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


#################MAIN####################

If (!(Test-ProcHasAdmin))
{throw "You must be running as an administrator, please restart as administrator"}

Write-Output "Setting PowerShell ExecutionPolicy to Unrestricted..."
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force

#install Chocolatey
Write-Output "Installing Chockolatey..."
if($PowerShellMajorVersion -ge 3)
{
    Invoke-WebRequest $ChocoScriptUrl -UseBasicParsing|Invoke-Expression
}
else
{
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($ChocoScriptUrl))
}
Write-Output "Done"

#checking .NET version installed
Write-Output "Checking .NET Framework version..."
#if .NET >= 4.5.1 
if(($DotNetBuildVersion) -ge 378675)
{
  Write-Output ".NET version (4.5.1) or greater is installed."
  if($PowerShellMajorVersion -ge 4)
  {
        
    Write-Output "Installing and configuring sysmon"
    $SysmonDSCConfig = Join-Path -Path $DscConfigRoot -ChildPath "Sysmon"        
    if (!(Test-Path -Path $SysmonDSCConfig -PathType Container))
    {
        New-Item -Path $SysmonDSCConfig -Type Directory -Confirm:$false -Force|Out-Null
    }
    #Compile the configuration file to a MOF format
    SysmonDSC -OutputPath $SysmonDSCConfig|Out-Null
    #Run the configuration on localhost
    Start-DscConfiguration -Path $SysmonDSCConfig  -ComputerName localhost -Force -Wait
    while((Get-Service -Name Sysmon).Status -ne "Running")
    {
        Write-Output "Waiting for sysmon service to start"
        Start-Sleep 2
    }        
    Write-Output "Sysmon service started"

    Write-Output "Installing and configuring nxlog"
    $NxlogDSCConfig = Join-Path $DscConfigRoot "Nxlog"
    if (!(Test-Path -Path $NxlogDSCConfig  -PathType Container))
    {
       New-Item -Path $NxlogDSCConfig -Type Directory -Confirm:$false -Force|Out-Null 
    }
    NxLogDSC -OutputPath $NxlogDSCConfig|Out-Null    
    Start-DscConfiguration -Path $NxlogDSCConfig  -ComputerName localhost -Force -Wait
    while((Get-Service -Name nxlog).Status -ne "Running")
    {
        Write-Output "Waiting for Nxlog service to start"
        Start-Sleep 2
    }        
    Write-Output "Nxlog service started"

    Write-Output "Setting Vagent service"
    $VagentDSCConfig = Join-Path $DscConfigRoot "Vagent"
    if (!(Test-Path -Path $VagentDSCConfig -PathType Container))
    {
        New-Item -Path $VagentDSCConfig -Type Directory -Confirm:$false -Force|Out-Null
    }
    VAgentDSC -OutputPath $VagentDSCConfig|Out-Null
    Start-DscConfiguration -Path $VagentDSCConfig -ComputerName localhost -Force -Wait
    while((Get-Service -Name vagent).Status -ne "Running")
    {
        Write-Output "Waiting for Vagent service to start"
        Start-Sleep 2
    }
            
    Write-Output "Vagent service started"
    if($PowerShellMajorVersion -ge 5)
    {
       Write-Output "Installing nuget provider"
       Install-PackageProvider -Name "Nuget" -Scope AllUsers -Confirm:$false -Force|Out-Null
       Write-Output "Done"
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
    if((Console-Prompt -Caption "Restart computer?" -Message "Applying changes requires to restart this computer" -choice "&Yes=Yes", "&No=No" -default 1) -eq 0)
    {Restart-Computer -Confirm:$false}
    
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
    if((Console-Prompt -Caption "Restart computer?" -Message "Applying changes requires to restart this computer" -choice "&Yes=Yes", "&No=No" -default 1) -eq 0)
    {Restart-Computer -Confirm:$false}        
}



