param(
    [parameter(Mandatory=$true)]
    $resourceGroupSource,
    [parameter(Mandatory=$true)]
    $resourceGroupTarget,
    [parameter(Mandatory=$true)]
    $webAppSourceName,
    [parameter(Mandatory=$true)]
    $webAppTargetName,
    [parameter(Mandatory=$true)]
    $subscriptionId
)

function Export-AppSettings ($webApp) 
{

    $webAppName = $webApp.Name    
    $appSettingsFileName = "$($webAppName)_appSettings.csv"
    $connectionStringsFileName = "$($webAppName)_connectionStrings.csv"
    $appSettingsExportPath = Join-Path $script:rootPath $appSettingsFileName
    $connectionStringsExportPath = Join-Path $script:rootPath $connectionStringsFileName
    
    Write-Host "Exporting $webAppName ..."
    $appSettings = $webApp.SiteConfig.AppSettings 
    If ($appSettings -ne $null) 
    {
        Write-Host "Exporting App Settings into csv..."
        $appSettings| Select-Object -Property Name, Value | Export-Csv -Path $appSettingsExportPath -NoTypeInformation
        Write-Host "App Settings saved at $appSettingsExportPath"

    }
    $connStrings = $webApp.SiteConfig.ConnectionStrings 
    If ($connStrings -ne $null) 
    {
        Write-Host "Exporting Connection Strings into csv..."
        $connStrings|Select-Object -Property Name, ConnectionString| Export-Csv -Path $connectionStringsExportPath -NoTypeInformation
        Write-Host "Connection Strings saved at $connectionStringsExportPath"
    }
    
}

$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Login-AzureRmAccount

Set-AzureRmContext -SubscriptionId $subscriptionId|Out-Null

# Load Existing Web App settings for source and target
Write-Host "Loading $webAppSourceName..."
$webAppSource = Get-AzureRmWebApp -ResourceGroupName $resourceGroupSource -Name $webAppSourceName
Write-Host "Loading $webAppTargetName"
$webAppTarget = Get-AzureRmWebApp -ResourceGroupName $resourceGroupSource -Name $webAppTargetName

#Export App Service settings firstly
Write-Warning "Export current App Service settings firstly..."
Export-AppSettings $webAppSource
Export-AppSettings $webAppTarget

# Get reference to the source Connection Strings
$connectionStringsSource = $webAppSource.SiteConfig.ConnectionStrings 

# Create Hash variable for Connection Strings
$connectionStringsTarget = @{}

# Copy over all Existing Connection Strings to the Hash
ForEach($connStringSource in $connectionStringsSource) {
    $connectionStringsTarget[$connStringSource.Name] = `
         @{ Type = $connStringSource.Type.ToString(); `
            Value = $connStringSource.ConnectionString }
}

# Save Connection Strings to Target
Write-Host "Migrating ConnectionStrings from $webAppSourceName into $webAppTargetName"
Set-AzureRmWebApp -ResourceGroupName $resourceGroupTarget -Name $webAppTargetName `
    -ConnectionStrings $connectionStringsTarget|Out-Null
Write-Host "ConnectionStrings has been migrated"

# Get reference to the source app settings
$appSettingsSource = $webAppSource.SiteConfig.AppSettings

# Create Hash variable for App Settings
$appSettingsTarget = @{}

# Copy over all Existing App Settings to the Hash
ForEach ($appSettingSource in $appSettingsSource) {
    $appSettingsTarget[$appSettingSource.Name] = $appSettingSource.Value
}

# Save App Settings to Target
Write-Host "Migrating App Settings from $webAppSourceName into $webAppTargetName"
Set-AzureRmWebApp -ResourceGroupName $resourceGroupTarget -Name $webAppTargetName `
   -AppSettings $appSettingsTarget|Out-Null
   Write-Host "App Settings has been migrated"