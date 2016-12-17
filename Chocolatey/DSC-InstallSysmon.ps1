#Requires -Version 4.0
#Requires -RunAsAdministrator

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

if (-not(test-path -Path C:\DSC\Sysmon -PathType Container))
{
    mkdir C:\DSC\Sysmon
}
# Compile the configuration file to a MOF format
 SysmonDSC -OutputPath C:\DSC\Sysmon

# Run the configuration on localhost
Start-DscConfiguration -Path C:\DSC\Sysmon  -ComputerName localhost -Verbose -Wait
