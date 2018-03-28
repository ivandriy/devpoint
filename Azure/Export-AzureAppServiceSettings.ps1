param(    
    [System.Management.Automation.PSCredential]$Credential,    
    $subscriptionId,    
    $webAppName
)

if ($Credential -eq $null) {
    Login-AzureRmAccount | Out-Null
}
else {
    Login-AzureRmAccount -Credential $Credential | Out-Null
}

if ($subscriptionId -eq $null) {
    $subscriptions = Get-AzureRmSubscription
    Write-Host "Azure Subscriptions"
    Write-Host "Index | Name | Id"
    For ($i = 0; $i -lt $subscriptions.count; $i++) {
        Write-Host $i")" $subscriptions[$i].Name":" $subscriptions[$i].Id
    }

    $subsIndex = Read-Host  -Prompt 'Select index'
    $subscriptionId = $subscriptions[$subsIndex].Id
}

Set-AzureRmContext -SubscriptionId $subscriptions[$subsIndex].Id |Out-Null

if ($webAppName -eq $null) {
    $webApps = Get-AzureRmWebApp
    Write-Host "WebApps"
    Write-Host "Index | Name"
    For ($i = 0; $i -lt $webApps.count; $i++) {
        Write-Host $i")" $webApps[$i].Name
    }

    $webAppIndex = Read-Host  -Prompt 'Select index'
    $webAppName = $webApps[$webAppIndex].Name
}

$webApp = Get-AzureRmWebApp -Name $webAppName


$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$appSettingsFileName = "$($webAppName)_appSettings.csv"
$connectionStringsFileName = "$($webAppName)_connectionStrings.csv"
$appSettingsExportPath = Join-Path $rootPath $appSettingsFileName
$connectionStringsExportPath = Join-Path $rootPath $connectionStringsFileName

# Load Web App settings
Write-Host "Loading $($webAppName) App Settings"
if ($webApp -ne $null) {
    $appSettings = $webApp.SiteConfig.AppSettings | Select-Object -Property Name, Value 
    If ($appSettings -ne $null) {
        Write-Host "Exporting App Settings into csv..."
        $appSettings| Export-Csv -Path $appSettingsExportPath -NoTypeInformation
        Write-Host "App Settings saved at $appSettingsExportPath"

    }
    $connStrings = $webApp.SiteConfig.ConnectionStrings | Select-Object -Property Name, ConnectionString 
    If ($connStrings -ne $null) {
        Write-Host "Exporting Connection Strings into csv..."
        $connStrings| Export-Csv -Path $connectionStringsExportPath -NoTypeInformation
        Write-Host "Connection Strings saved at $connectionStringsExportPath"
    }

}
else {
    Write-Error "Cannot load $webAppName from resource group $resourceGroup - check your settings..."
    exit 1
}
