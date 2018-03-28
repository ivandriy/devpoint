param(
    [parameter(Mandatory=$true)]
    $resourceGroup,
    [parameter(Mandatory=$true)]
    $webAppName,
    [parameter(Mandatory=$true)]
    $subscriptionId
)

$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$appSettingsFileName = "$($webAppName)_appSettings.csv"
$connectionStringsFileName = "$($webAppName)_connectionStrings.csv"
$appSettingsExportPath = Join-Path $rootPath $appSettingsFileName
$connectionStringsExportPath = Join-Path $rootPath $connectionStringsFileName
Login-AzureRmAccount

Set-AzureRmContext -SubscriptionId $subscriptionId|Out-Null

# Load Web App settings
Write-Host "Loading $($webAppName) App Settings"
$webApp = Get-AzureRmWebApp -ResourceGroupName $resourceGroup -Name $webAppName

if($webApp -ne $null)
{
    $appSettings = $webApp.SiteConfig.AppSettings | Select-Object -Property Name, Value 
    If ($appSettings -ne $null) 
    {
        Write-Host "Exporting App Settings into csv..."
        $appSettings| Export-Csv -Path $appSettingsExportPath -NoTypeInformation
        Write-Host "App Settings saved at $appSettingsExportPath"

    }
    $connStrings = $webApp.SiteConfig.ConnectionStrings | Select-Object -Property Name, ConnectionString 
    If ($connStrings -ne $null) 
    {
        Write-Host "Exporting Connection Strings into csv..."
        $connStrings| Export-Csv -Path $connectionStringsExportPath -NoTypeInformation
        Write-Host "Connection Strings saved at $connectionStringsExportPath"
    }

}
else {
    Write-Error "Cannot load $webAppName from resource group $resourceGroup - check your settings..."
    exit 1
}



