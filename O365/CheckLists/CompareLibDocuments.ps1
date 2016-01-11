param
(
    [parameter(Mandatory=$true)]
    [string]$MossExportFolder,

    [parameter(Mandatory=$true)]
    [string]$SPOExportFolder
)

function Create-Report
{
    param(
        [Object[]]$ListToExport,
        $ReportFileName
    )

   if($ListToExport.Count -gt 0)
   {
     $CurrentDir = Split-Path -parent $script:MyInvocation.MyCommand.Path
     $SaveDir = $CurrentDir+"\Reports"
     if(!(Test-Path $SaveDir))
     {
        New-Item -ItemType Directory -Force -Path $SaveDir|Out-Null
     }
                    
     $OutputFileName = $ReportFileName +".csv"
     $OutputFilePath = $SaveDir+"\"+$OutputFileName        
     if (Test-Path $OutputFilePath)
     {
        Remove-Item $OutputFilePath
     }
             
     $ListToExport|Export-Csv $OutputFilePath -NoTypeInformation
     Write-Host "Report saved to: $OutputFilePath"
     Write-Host          
   }
}


$MossExportFiles = Get-ChildItem -Path $($MossExportFolder+"\*.*") -File -Include *.csv
$SPOExportFiles = @()

foreach ($mossfile in $MossExportFiles)
{
    if (Test-Path $($SPOExportFolder+"\$($mossfile.Name)"))
    {
        Write-Host "=========================================================="
        #Write-Host "Starting check for $($mossfile.Name)"
        $MissedDocs = @()
        $ModifiedDocs = @()
        $OKDocs = @()

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

        
        #Write-Host "   missed files count: $($MissedDocs.Count)"
        #$MissedDocs|Format-Table -AutoSize -Wrap -Property Name,RelativeUrl,Modified
        #Write-Host "   files with non matched modified date: $($ModifiedDocs.Count)"
        #$ModifiedDocs|Format-Table -AutoSize -Wrap -Property Name,RelativeUrl,MossModified,SPOModified
        #Write-Host "   other files: $($OKDocs.Count)"
        #$OKDocs|Format-Table -AutoSize -Wrap -Property Name,RelativeUrl,Url

        if($MissedDocs.Count -gt 0)
        {
            Create-Report -ListToExport $MissedDocs -ReportFileName $($mossfile.Name+"_missed")
        }
        
        if($ModifiedDocs.Count -gt 0)
        {
            Create-Report -ListToExport $ModifiedDocs -ReportFileName $($mossfile.Name+"_modified")
        }
        
        Write-Host "=========================================================="
        Write-Host
    }
    else
    {
        Write-Host "SPO export file not found: $($SPOExportFolder+"\$($mossfile.Name)")" -ForegroundColor Yellow
    }
}

