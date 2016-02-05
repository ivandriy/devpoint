param (
    [parameter(Mandatory=$true)]
    $MossDocumentsFile,
    [parameter(Mandatory=$true)]
    $SPODocumentsFile
)

function Write-ToLogFile
{
    
    param(
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullOrEmpty()] 
        [string]$Message,
        
        [Parameter(Mandatory=$true)] 
        [string]$Path,
          
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info",

        [switch]
        $ConsoleOut
    )
    Begin 
    { 
    } 
    Process 
    {         
        if (!(Test-Path $Path)) 
        { 
            New-Item $Path -Force -ItemType File|Out-Null
        } 
        
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
        switch ($Level) { 
            'Error' {  
                $LevelText = 'ERROR:'
                $ForgroundCol = 'Red' 
                } 
            'Warn' {  
                $LevelText = 'WARNING:'
                $ForgroundCol = 'Yellow' 
                } 
            'Info' {  
                $LevelText = 'INFO:'
                $ForgroundCol = 'White' 
                } 
            }
        
        $OutputLine = "$FormattedDate $LevelText $Message"
        if($ConsoleOut) 
        {
            Write-Host  $Message -ForegroundColor $ForgroundCol    
        }
        $OutputLine| Out-File -FilePath $Path -Append
    } 
    End 
    {
     
    } 
}


function Export-ToCsvFile
{
    param(
        [Object[]]$ListToExport,
        $CsvFileName
    )

   if($ListToExport.Count -gt 0)
   {
     $CurrentDir = Split-Path -parent $script:MyInvocation.MyCommand.Path
     $SaveDir = $CurrentDir+"\Output"
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
     Write-Host
     Write-Host "File saved to: $OutputFilePath"
               
   }
}

$TargetDir = Split-Path -parent $script:MyInvocation.MyCommand.Path
$CurrentDir = Split-Path -parent $MyInvocation.MyCommand.Path
$FormattedDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFilePath = $TargetDir+"\CompareDocuments_$($FormattedDate).log"


#region Comparing documents

$MissedDocs = @()
$ModifiedDocs = @()

Write-Host
Write-ToLogFile -Message "Loading MOSS documents from: $($MossDocumentsFile)" -Path $LogFilePath -Level Info -ConsoleOut
if(Test-Path $MossDocumentsFile)
{
    $MossTable = Import-Csv -Path $MossDocumentsFile    
}
else
{
    throw "File $($MossDocumentsFile) was not found"
}

Write-Host
Write-ToLogFile -Message "Loading SPO documents from: $($SPODocumentsFile)" -Path $LogFilePath -Level Info -ConsoleOut
if(Test-Path $SPODocumentsFile)
{
    $LibraryDocs = Import-Csv -Path $SPODocumentsFile    
}
else
{
    throw "File $($SPODocumentsFile) was not found"
}


$MossDocs=@{}
$SPODocs = @{}
$OKDocs = @()

foreach($line in $MossTable)
{
    $MossDocs[$line.RelativeUrl]=$line
}

foreach($doc in $LibraryDocs)
{
    $SPODocs[$doc.RelativeUrl]=$doc
}


foreach ($doc in $MossDocs.Keys)
        {

            if($SPODocs.ContainsKey($doc))
            {
                $SPODocumentUrl = ($SPODocs.Item($doc)).Url
                $DocumentName = ($SPODocs.Item($doc)).Name
                $DocumentRelUrl = ($SPODocs.Item($doc)).RelativeUrl

                Write-ToLogFile -Message "Processing document: $($DocumentRelUrl)" -Path $LogFilePath -Level Info -ConsoleOut
                
                $SPODocModDate = ($SPODocs.Item($doc)).Modified
                $MOSSDocModDate = ($MossDocs.Item($doc)).Modified
                Write-ToLogFile -Message "SPODocModDate: $($SPODocModDate); MOSSDocModDate: $($MOSSDocModDate)" -Path $LogFilePath -Level Info 

                [System.Globalization.CultureInfo]$provider = [System.Globalization.CultureInfo]::InvariantCulture
                
                $format = "M/d/yyyy HH:mm:ss"
                
                [System.DateTime]$parsedDateMoss = get-date
                [System.DateTime]$parsedDateSpo = get-date
                
                [DateTime]::TryParseExact($MOSSDocModDate,$format,$provider,[System.Globalization.DateTimeStyles]::None,[ref]$parsedDateMoss)|Out-Null
                [DateTime]::TryParseExact($SPODocModDate,$format,$provider,[System.Globalization.DateTimeStyles]::None,[ref]$parsedDateSpo)|Out-Null

                Write-ToLogFile -Message "SPODocModDateParsed: $($parsedDateSpo); MOSSDocModDateParsed: $($parsedDateMoss)" -Path $LogFilePath -Level Info
                $formatedDateSpo = $parsedDateSpo.ToString($format)
                $formatedDateMoss = $parsedDateMoss.ToString($format)

                $docobj=New-Object -TypeName PSObject
                $docobj|Add-Member -Name "Name" -MemberType Noteproperty -Value $DocumentName
                $docobj|Add-Member -Name "RelativeUrl" -MemberType Noteproperty -Value $DocumentRelUrl
                $docobj|Add-Member -Name "Url" -MemberType Noteproperty -Value $SPODocumentUrl
                $docobj|Add-Member -Name "MossModified" -MemberType Noteproperty -Value $formatedDateMoss
                $docobj|Add-Member -Name "SPOModified" -MemberType Noteproperty -Value $formatedDateSpo
                
                if($parsedDateSpo -gt $parsedDateMoss)
                {
                    $ModifiedDocs += $docobj
                    Write-ToLogFile -Message "Document was modified on SPO! SPO LastModified(UTC): $($parsedDateSPO.ToString($format2)); MOSS LastModified(UTC): $($parsedDateMOSS.ToString($format2))" -Path $LogFilePath -Level Warn
                      
                }
                elseif ($parsedDateSpo -lt $parsedDateMoss)
                {
                   $ModifiedDocs += $docobj
                    Write-ToLogFile -Message "Document was modified on MOSS! MOSS LastModified(UTC): $($parsedDateMOSS.ToString($format2)); SPO LastModified(UTC): $($parsedDateSPO.ToString($format2)) " -Path $LogFilePath -Level Warn
                }

                else
                {
                    $OKDocs += $docobj
                    Write-ToLogFile -Message "Last modified ok! SPO LastModified(UTC): $($parsedDateSPO.ToString($format2)); MOSS LastModified(UTC): $($parsedDateMOSS.ToString($format2))" -Path $LogFilePath -Level Info
                } 

            }
            else
            {
                $MissedDocs += $MossDocs.Item($doc)
                Write-ToLogFile -Message "Document was not found: $($doc)" -Path $LogFilePath -Level Warn -ConsoleOut
            }
        }

$Tables = @()
if($MissedDocs.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $MissedDocs -CsvFileName "MissingDocuments"
   Write-ToLogFile -Message "Missed documents saved to $($CurrentDir)\Output\MissingDocuments.csv" -Path $LogFilePath -Level Info
   $Pre = "<h3>Missed Documents: $($MissedDocs.Count) total</h3>"
   $table = $MissedDocs|ConvertTo-Html -PreContent $Pre -Fragment -Property Url,Modified
   $table += "<td>"
   $Tables += $table
}
        
if($ModifiedDocs.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $ModifiedDocs -CsvFileName "ModifiedDocuments"
   Write-ToLogFile -Message "Modified documents saved to $($CurrentDir)\Output\ModifiedDocuments.csv" -Path $LogFilePath -Level Info
   $Pre = "<h3>Modified Documents: $($ModifiedDocs.Count) total</h3>"
   $table = $ModifiedDocs|ConvertTo-Html -PreContent $Pre -Fragment -Property Url,MossModified,SPOModified
   $table += "<td>"
   $Tables += $table
}

if($OKDocs.Count -gt 0)
{
   Export-ToCsvFile -ListToExport $OKDocs -CsvFileName "OKDocuments"
   Write-ToLogFile -Message "Modified documents saved to $($CurrentDir)\Output\OKDocuments.csv" -Path $LogFilePath -Level Info
   #$Pre = "<h3>OK Documents: $($OKDocs.Count) total</h3>"
   #$table = $ModifiedDocs|ConvertTo-Html -PreContent $Pre -Fragment -Property Url,MossModified,SPOModified
   #$table += "<td>"
   #$Tables += $table
}
#endregion

#region Make HTML report
$Head =
@"
    <style>
	BODY {
		font-family:Verdana; 
		background-color:white; 
		font-size:12px
	}
    TABLE {
        border-width: 1px;
        border-style: solid;
        border-color: black;
        border-collapse: collapse;
     }
     TH {
        font-size: 16px;
        font-weight: bold;
        text-align: left;
        color:white;
        font-family:Verdana;
        padding:5px;
        border-top:.5pt solid #93CDDD;
        border-right:.5pt solid #93CDDD;
        border-bottom:.5pt solid #93CDDD;
        border-left:.5pt solid #93CDDD;
        background:#4BACC6;
     }
     TD {
        font-size:12px;
        color:black;
        text-decoration:none;
        padding:5px;
        font-family:Verdana;
        border-top:.5pt solid #93CDDD;
        border-right:.5pt solid #93CDDD;
        border-left:.5pt solid #93CDDD;
        border-bottom:.5pt solid #93CDDD;
     }
    </style>
"@

$Body = @"
    <br>
    <div align="right"><B>Report generated at $(get-date)</b></div><hr color=black height=10px align=left width=100%>
	<br>
    <h3>Missing and modified lists/documents
    <td>
    <div align="left"><B>MOSS documents: $($MossTable.Count); SPO documents: $($LibraryDocs.Count)</b></div><hr color=black height=10px align=left width=100%>
     
"@

$HtmlReportFilePath = $CurrentDir+"\Output\Report.html"
if($Tables)
{
    $Body += $Tables
    ConvertTo-Html -Head $Head -Body $Body -Title "Missing/modified items"|Out-File $HtmlReportFilePath
    Write-Host
    Write-Host "Report saved to: $HtmlReportFilePath" -ForegroundColor Green
}
#endregion
Write-Host "Done!" -ForegroundColor Green