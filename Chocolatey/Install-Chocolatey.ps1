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

function Console-Prompt 
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
                    Result  = $(Test-Path (Join-Path -Path ($($Env:ChocolateyInstall)) -ChildPath '\lib\sysmon\tools\sysmon.exe') -PathType Leaf);
                }
            }
            SetScript = {
                Write-Verbose -Message "Download Sysmon using choco"
                Choco Install -y sysmon --ignore-checksums
                Write-Verbose -Message "Done!"
            }
            TestScript = {
                $sysmonPath = Join-Path $($Env:ChocolateyInstall) '\lib\sysmon\tools\sysmon.exe'
                if(Test-Path -Path $sysmonPath -PathType Leaf) 
                {
                    Write-Verbose -Message "Sysmon is already exists in $sysmonPath"
                    return $true
                } else 
                {
                    Write-Verbose -Message "Sysmon isn't exists"
                    return $false
                }
            }
        }
        Script SetupSysmon {
            GetScript = {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result  = $();
                }
            }
            SetScript = {
                Write-Verbose -Message "Setup and start Sysmon services..."
                $sysmonPath = Join-Path $Env:ChocolateyInstall "lib\sysmon\tools"
                $configPath = Join-Path $sysmonPath "sysmon.xml"                
                $sysmon = (Join-Path $sysmonPath "sysmon.exe")
                $argsuments = "-i $configPath -accepteula"
                $proc = Start-Process -FilePath $sysmon -ArgumentList $argsuments -WorkingDirectory $sysmonPath -PassThru -RedirectStandardError "$sysmonPath\error.log" -Wait
                if($proc.ExitCode -ne 0)
                {throw "Sysmon services are not started - check $sysmonPath\error.log for details"}
                else
                {
                    while( ((Get-Service -Name Sysmon).Status -ne "Running") -and ((Get-Service -Name Sysmondrv).Status -ne "Running"))
                    {
                        Write-Verbose -Message "Waiting for sysmon services to start"
                        Start-Sleep 2
                    }        
                    Write-Verbose -Message "Sysmon services are started"
                }
            }
            TestScript = {                 
                if(($null -eq (Get-Service -Name Sysmon -ErrorAction:SilentlyContinue)) -and ($null -eq (Get-Service -Name Sysmondrv -ErrorAction:SilentlyContinue))) 
                {
                    Write-Verbose -Message "Sysmon services are missed"
                    return $false
                } 
                else 
                {
                    Write-Verbose -Message "Sysmon services are present"
                    return $true
                }
            }
           DependsOn = '[Script]DownloadSysmon','[File]SysmonConfig'
        }        
        File  SysmonConfig {
            DestinationPath = Join-Path $($Env:ChocolateyInstall) '\lib\sysmon\tools\sysmon.xml'
            Ensure = 'Present';
            Force = $true
            Contents = @'
<Sysmon schemaversion="3.10">
  <HashAlgorithms>*</HashAlgorithms>
</Sysmon>
'@
        }
        Service SysmonService
        {
            Name        = "Sysmon"            
            State       = "Running"
        }
        Service SysmonDrvService
        {
            Name        = "Sysmondrv"            
            State       = "Running"
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
        Script InstallNxlog {
            GetScript = {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript                                        
                    Result  = $(Get-Service -Name nxlog -ErrorAction:SilentlyContinue);                    
                }
            }
            SetScript = {                
                try
                {
                  Write-Verbose -Message 'Installing nxlog using choco...'  
                  Choco install -y nxlog
                  Write-Verbose -Message 'Successfully installed nxlog' 
                }
                catch
                {
                    throw $_
                }                
            }
            TestScript = { 
                if((Test-Path (Join-Path -Path (${Env:ProgramFiles(x86)}) -ChildPath 'nxlog\nxlog.exe') -PathType Leaf))
                {
                    Write-Verbose -Message "Nxlog is installed"
                    return $true
                } 
                else
                {
                    Write-Verbose -Message "Nxlog isn't installed"
                    return $false
                }
            }
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
                    if((Get-FileHash -Path $configPath).Hash -ne (Get-FileHash -Path $tmpfile).Hash)
                    {
                        Write-Verbose -Message "Nxlog config need to be updated"
                        return $false
                    }                    
                    else
                    {
                        Write-Verbose -Message "Nxlog config is up to date"
                        return $true 
                    }
                }
                else
                {
                    Write-Verbose -Message "Nxlog config not found"
                    return $false
                }                
            }
            DependsOn = '[Script]InstallNxlog'
        }

        Service NxlogService
        {
            Name        = "nxlog"            
            State       = "Running"
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
    Write-Output "Sysmon configured"

    Write-Output "Installing and configuring nxlog"
    $NxlogDSCConfig = Join-Path $DscConfigRoot "Nxlog"
    if (!(Test-Path -Path $NxlogDSCConfig  -PathType Container))
    {
       New-Item -Path $NxlogDSCConfig -Type Directory -Confirm:$false -Force|Out-Null 
    }
    NxLogDSC -OutputPath $NxlogDSCConfig|Out-Null    
    Start-DscConfiguration -Path $NxlogDSCConfig  -ComputerName localhost -Force -Wait        
    Write-Output "Nxlog configured"

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



