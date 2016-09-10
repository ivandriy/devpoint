
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
    if($InputString)
    {
        if($InputString -match '^"*(\w{1}:\\.*\.\w{3,}).*$')
        {$UninstallPath=$Matches[1]} 
    }      
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
                        if($ProgramName -eq '')                        
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


function Escape-JSONString($str){
	if ($str -eq $null) {return ""}
	$str = $str.ToString().Replace('"','\"').Replace('\','\\').Replace("`n",'\n').Replace("`r",'\r').Replace("`t",'\t')
	return $str;
}

function ConvertTo-JSONFunc($maxDepth = 4,$forceArray = $false) {
	begin {
		$data = @()
	}
	process{
		$data += $_
	}
	
	end{
	
		if ($data.length -eq 1 -and $forceArray -eq $false) {
			$value = $data[0]
		} else {	
			$value = $data
		}

		if ($value -eq $null) {
			return "null"
		}

		

		$dataType = $value.GetType().Name
		
		switch -regex ($dataType) {
	            'String'  {
					return  "`"{0}`"" -f (Escape-JSONString $value )
				}
	            '(System\.)?DateTime'  {return  "`"{0:yyyy-MM-dd}T{0:HH:mm:ss}`"" -f $value}
	            'Int32|Double' {return  "$value"}
				'Boolean' {return  "$value".ToLower()}
	            '(System\.)?Object\[\]' { # array
					
					if ($maxDepth -le 0){return "`"$value`""}
					
					$jsonResult = ''
					foreach($elem in $value){
						#if ($elem -eq $null) {continue}
						if ($jsonResult.Length -gt 0) {$jsonResult +=', '}				
						$jsonResult += ($elem | ConvertTo-JSONFunc -maxDepth ($maxDepth -1))
					}
					return "[" + $jsonResult + "]"
	            }
				'(System\.)?Hashtable' { # hashtable
					$jsonResult = ''
					foreach($key in $value.Keys){
						if ($jsonResult.Length -gt 0) {$jsonResult +=', '}
						$jsonResult += 
@"
	"{0}": {1}
"@ -f $key , ($value[$key] | ConvertTo-JSONFunc -maxDepth ($maxDepth -1) )
					}
					return "{" + $jsonResult + "}"
				}
	            default { #object
					if ($maxDepth -le 0){return  "`"{0}`"" -f (Escape-JSONString $value)}
					
					return "{" +
						(($value | Get-Member -MemberType *property | % { 
@"
	"{0}": {1}
"@ -f $_.Name , ($value.($_.Name) | ConvertTo-JSONFunc -maxDepth ($maxDepth -1) )			
					
					}) -join ', ') + "}"
	    		}
		}
	}
}
	

############MAIN##############
$InstalledPrograms = @()
$PowerShellMajorVersion = $PSVersionTable.PSVersion.Major
$PowerShellMinorVersion = $PSVersionTable.PSVersion.Minor
if(($PowerShellMajorVersion -ge 5) -and ($PowerShellMinorVersion -ge 1))
{
    $InstalledPrograms = Get-ProgramsFromRegistry
    $InstalledPrograms += Get-Package -ProviderName Programs|Select-Object -Property @{Name='DisplayName'; Expression={($_.Name)}} `
                ,@{Name='DisplayVersion'; Expression={($_.Version)}} `
                ,@{Name='DisplayIcon'; Expression={($_.Metadata['DisplayIcon'])}}`
                ,@{Name='InstallDate'; Expression={($_.Metadata['InstallDate'])}}`
                ,@{Name='InstallLocation'; Expression={($_.Metadata['InstallLocation'])}}`
                ,@{Name='InstallSource'; Expression={($_.Source)}}`
                ,@{Name='Publisher'; Expression={($_.Metadata['Publisher'])}}`
                ,@{Name='UninstallCommand'; Expression={($_.Metadata['UninstallString'])}}`
                ,@{Name='PathToUninstall';Expression={Get-UninstallPath -InputString $($_.Metadata['UninstallString']) }} 
}
else
{
    $InstalledPrograms = Get-ProgramsFromRegistry      
}

$InstalledPrograms = $InstalledPrograms|Sort-Object -Property DisplayName -Unique

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

if($PowerShellMajorVersion -lt 3)
{
    $AllPrograms|Select-Object -Property DisplayName,DisplayVersion,DisplayIcon,InstallDate,InstallLocation,Publisher,UninstallCommand,PathToUninstall,MD5Hash,SH1Hash,SH256Hash,DigitalSignature|ConvertTo-JSONFunc
}
else
{
    $AllPrograms|Select-Object -Property DisplayName,DisplayVersion,DisplayIcon,InstallDate,InstallLocation,Publisher,UninstallCommand,PathToUninstall,MD5Hash,SH1Hash,SH256Hash,DigitalSignature|ConvertTo-Json
}
