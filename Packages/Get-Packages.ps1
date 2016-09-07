#Requires -Version 5.0
#$PowerShellVersion = $PSVersionTable.PSVersion.Major

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

############MAIN##############

$programs=Get-Package -ProviderName Programs|Select-Object -Property Name,Version `
                ,@{Name='UninstallCommand'; Expression={($_.Metadata['UninstallString'])}}`
                ,@{Name='PathToUninstall';Expression={Get-UninstallPath -InputString $($_.Metadata['UninstallString']) }}                

$AllPrograms = @()
foreach($program in $programs)
{
    $md5hash = $null
    $sh1hash = $null
    $sh256hash = $null    
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
        Name = $program.Name
        Version = $program.Version
        UninstallCommand = $program.UninstallCommand
        PathToUninstall = $program.PathToUninstall
        MD5Hash = $md5hash
        SH1Hash = $sh1hash
        SH256Hash = $sh256hash
        DigitalSignature = $sign
    }
}

$AllPrograms|Select-Object -Property Name,Version,UninstallCommand,PathToUninstall,MD5Hash,SH1Hash,SH256Hash,DigitalSignature|ConvertTo-Json