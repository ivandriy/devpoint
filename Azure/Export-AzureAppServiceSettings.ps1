param(
    $resourceGroup = "DevelopmentRD",
    $webAppName = "CertifID-Dev-Server"
)

$subscriptionId = "b704bb27-cd2b-4463-82c8-f9456c07a3a6"
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
    $connStrings = $webApp.SiteConfig.ConnectionStrings | Select-Object -Property Name, Type, ConnectionString 
    If ($connStrings -ne $null) 
    {
        Write-Host "Exporting Connection Strings into csv..."
        $connectionStringsExportPath| Export-Csv -Path $connectionStringsFileName -NoTypeInformation
        Write-Host "Connection Strings saved at $connectionStringsFileName"
    }

}
else {
    Write-Error "Cannot load $webAppName from resource group $resourceGroup - check your settings..."
    exit 1
}



