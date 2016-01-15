param
(
    [parameter(Mandatory=$true)]
    [string]$MossExportFolder,

    [parameter(Mandatory=$true)]
    [string]$SPOExportFolder
)

function Export-ToCsvFile
{
    param(
        [Object[]]$ListToExport,
        $CsvFileName
    )

   if($ListToExport.Count -gt 0)
   {
     $CurrentDir = Split-Path -parent $script:MyInvocation.MyCommand.Path
     $SaveDir = $CurrentDir+"\Reports"
     if(!(Test-Path $SaveDir))
     {
        New-Item -ItemType Directory -Force -Path $SaveDir|Out-Null
     }
                    
     $OutputFileName = $CsvFileName +".csv"
     $OutputFilePath = $SaveDir+"\"+$OutputFileName        
     if (Test-Path $OutputFilePath)
     {
        Remove-Item $OutputFilePath
     }
             
     $ListToExport|Export-Csv $OutputFilePath -NoTypeInformation
     Write-Host "File saved to: $OutputFilePath"
     Write-Host          
   }
}


$MossExportFiles = Get-ChildItem -Path $($MossExportFolder+"\*.*") -File -Include *.csv
$MissedDocs = @()
$ModifiedDocs = @()

foreach ($mossfile in $MossExportFiles)
{
    if (Test-Path $($SPOExportFolder+"\$($mossfile.Name)"))
    {
        
        $MossTable = Import-Csv -Path $mossfile.FullName
        $SPOTable = Import-Csv -Path $($SPOExportFolder+"\$($mossfile.Name)")

        $MossDocs=@{}
        $SPODocs = @{}

        foreach($line in $MossTable)
        {
            $MossDocs[$line.RelativeUrl]=$line
        }

        foreach($line in $SPOTable)
        {
            $SPODocs[$line.RelativeUrl]=$line
        }

        foreach ($doc in $MossDocs.Keys)
        {
            if($SPODocs.ContainsKey($doc))
            {
                $SPODocModDate = ($SPODocs.Item($doc)).Modified
                $MOSSDocModDate = ($MossDocs.Item($doc)).Modified
                $SPODocumentUrl = ($SPODocs.Item($doc)).Url
                $DocumentName = ($SPODocs.Item($doc)).Name
                $DocumentRelUrl = ($SPODocs.Item($doc)).RelativeUrl

                $docobj=New-Object -TypeName PSObject
                $docobj|Add-Member -Name "Name" -MemberType Noteproperty -Value $DocumentName
                $docobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $DocumentRelUrl
                $docobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $SPODocumentUrl
                $docobj|Add-Member -Name "MossModified" -MemberType Noteproperty -Value $MOSSDocModDate
                $docobj|Add-Member -Name "SPOModified" -MemberType Noteproperty -Value $SPODocModDate
                 
                if( $SPODocModDate -ne $MOSSDocModDate )
                {
                    $ModifiedDocs += $docobj  
                }
                else
                {
                    $OKDocs += $docobj  
                } 

            }
            else
            {
                $MissedDocs += $MossDocs.Item($doc)
            }
        }
        
    }
}

if($MissedDocs.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $MissedDocs -CsvFileName "MissingDocuments"
}
        
if($ModifiedDocs.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $ModifiedDocs -CsvFileName "ModifiedDocuments"
}

