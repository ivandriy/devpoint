#Requires -Version 5.0


###########FUNCTIONS###############
function Get-Hash
{
    param(
        $FilePath,
        $HashType
    )

    retrun Get-FileHash $FilePath -Algorithm $HashType
}

function Get-UninstallPath
{
    param(
        $InputString
    )
    [string]$UninstallPath = $null
    $Matches= $null
    if($InputString -match '^"*(\w{1}:\\.*\.\w{3,}).*$')
    {$UninstallPath=$Matches[1]}    
    return $UninstallPath
}

function Get-ProgramsFromRegistry
{    
    $ProgramsList = @()
    $RegistryLocation = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\',
                        'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
    $RegBase = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$env:COMPUTERNAME)
    foreach ($UninstallKey in $RegistryLocation)
    {
        if ($RegBase)
        {
            $CurrentRegKey = $RegBase.OpenSubKey($UninstallKey)
            if($CurrentRegKey)
            {
                $Subkeys = $CurrentRegKey.GetSubKeyNames()
                if($Subkeys)
                {
                    foreach($key in $Subkeys)
                    {
                        $ThisKey = $UninstallKey+"\\"+$key
                        $ThisSubKey = $RegBase.OpenSubKey($ThisKey)
                        $ProgramName = $ThisSubKey.GetValue("DisplayName")
                        if([string]::IsNullOrWhiteSpace($ProgramName))                        
                        {
                            if(!($key.StartsWith('{')))
                            {
                                $ProgramName = $key
                            }
                            else
                            {
                             continue
                            }
                        }                        
                        $ProgramsList += New-Object -TypeName psobject -Property @{
                                DisplayName = $ProgramName
                                DisplayVersion = $ThisSubKey.GetValue("DisplayVersion")
                                DisplayIcon = $ThisSubKey.GetValue("DisplayIcon")                                
                                InstallDate = $ThisSubKey.GetValue("InstallDate")
                                InstallLocation = $ThisSubKey.GetValue("InstallLocation")
                                InstallSource = $ThisSubKey.GetValue("InstallSource")
                                Publisher = $ThisSubKey.GetValue("Publisher")
                                UninstallString = $ThisSubKey.GetValue("UninstallString")
                                PathToUninstall = Get-UninstallPath -InputString $ThisSubKey.GetValue("UninstallString")
                            }
                    }
                }
            }
        }
    }

    return $ProgramsList
}
############MAIN##############
$InstalledPrograms = @()
$PowerShellVersion = $PSVersionTable.PSVersion.Major
if($PowerShellVersion -lt 5)
{
    $InstalledPrograms = Get-ProgramsFromRegistry
}
else
{
    $InstalledPrograms=Get-Package -ProviderName Programs|Select-Object -Property @{Name='DisplayName'; Expression={($_.Name)}} `
                ,@{Name='DisplayVersion'; Expression={($_.Version)}} `
                ,@{Name='DisplayIcon'; Expression={($_.Metadata['DisplayIcon'])}}`
                ,@{Name='InstallDate'; Expression={($_.Metadata['InstallDate'])}}`
                ,@{Name='InstallLocation'; Expression={($_.Metadata['InstallLocation'])}}`
                ,@{Name='InstallSource'; Expression={($_.Source)}}`
                ,@{Name='Publisher'; Expression={($_.Metadata['Publisher'])}}`
                ,@{Name='UninstallCommand'; Expression={($_.Metadata['UninstallString'])}}`
                ,@{Name='PathToUninstall';Expression={Get-UninstallPath -InputString $($_.Metadata['UninstallString']) }} 
}

$AllPrograms = @()
foreach($program in $InstalledPrograms)
{
    $md5hash = $null
    $sh1hash = $null
    $sh256hash = $null
    $sign = $null    
    if($program.PathToUninstall -ne '')
    {                
        if((Test-Path $program.PathToUninstall -IsValid) -and (Test-Path $program.PathToUninstall))
        {
            $md5hash = (Get-FileHash $program.PathToUninstall -Algorithm MD5).Hash
            $sh1hash = (Get-FileHash $program.PathToUninstall -Algorithm SHA1).Hash
            $sh256hash = (Get-FileHash $program.PathToUninstall -Algorithm SHA256).Hash
            $sign = (Get-AuthenticodeSignature -FilePath $program.PathToUninstall).SignerCertificate.Thumbprint
        }
    }
    $AllPrograms += New-Object -TypeName psobject -Property @{
        DisplayName = $program.DisplayName
        DisplayVersion = $program.DisplayVersion
        DisplayIcon = $program.DisplayIcon
        InstallDate = $program.InstallDate
        InstallLocation = $program.InstallLocation
        Publisher = $program.Publisher
        UninstallCommand = $program.UninstallCommand
        PathToUninstall = $program.PathToUninstall
        MD5Hash = $md5hash
        SH1Hash = $sh1hash
        SH256Hash = $sh256hash
        DigitalSignature = $sign
    }
}

$AllPrograms|Select-Object -Property DisplayName,DisplayVersion,DisplayIcon,InstallDate,InstallLocation,Publisher,UninstallCommand,PathToUninstall,MD5Hash,SH1Hash,SH256Hash,DigitalSignature|ConvertTo-Json