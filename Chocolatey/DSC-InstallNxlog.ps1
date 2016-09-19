#Requires -Version 4.0
#Requires -RunAsAdministrator

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

if (-not(test-path -Path C:\DSC\Nxlog -PathType Container)){
    mkdir C:\DSC\Nxlog
}
# Compile the configuration file to a MOF format
 NxLogDSC -OutputPath C:\DSC\Nxlog

# Run the configuration on localhost
Start-DscConfiguration -Path C:\DSC\Nxlog  -ComputerName localhost -Force -Wait