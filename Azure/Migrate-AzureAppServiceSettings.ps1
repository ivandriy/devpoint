param(    
    $webAppSourceName,    
    $webAppTargetName,    
    $subscriptionId,
    [parameter(Mandatory=$true)]
    $resourceGroup
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

if ($Credential -eq $null) {
    Login-AzureRmAccount | Out-Null
}
else {
    Login-AzureRmAccount -Credential $Credential | Out-Null
}

if ($subscriptionId -eq $null) {
    $subscriptions = Get-AzureRmSubscription
    Write-Host "Azure Subscriptions"
    Write-Host "|Index|Name|Id|"
    For ($i = 0; $i -lt $subscriptions.count; $i++) {
        Write-Host $i"|" $subscriptions[$i].Name"|" $subscriptions[$i].Id
    }

    $subsIndex = Read-Host  -Prompt 'Select index'
    $subscriptionId = $subscriptions[$subsIndex].Id
}

Set-AzureRmContext -SubscriptionId $subscriptions[$subsIndex].Id |Out-Null

if (($webAppSourceName -eq $null) -or ($webAppTargetName -eq $null) ) {
    $webApps = Get-AzureRmWebApp -ResourceGroupName $resourceGroup
    Write-Host "WebApps"
    Write-Host "|Index| Name |"
    For ($i = 0; $i -lt $webApps.count; $i++) {
        Write-Host $i"|" $webApps[$i].Name
    }

    $webAppIndexS = Read-Host  -Prompt 'Select source application by index'
    $webAppSourceName = $webApps[$webAppIndexS].Name

    $webAppIndexT = Read-Host  -Prompt 'Select target application by index'
    $webAppTargetName = $webApps[$webAppIndexT].Name
}

$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load Existing Web App settings for source and target
Write-Host "Loading $webAppSourceName..."
$webAppSource = Get-AzureRmWebApp -Name $webAppSourceName
Write-Host "Loading $webAppTargetName"
$webAppTarget = Get-AzureRmWebApp -Name $webAppTargetName

#Export App Service settings firstly
Write-Warning "Export current App Service settings firstly..."
Export-AppSettings $webAppSource
Export-AppSettings $webAppTarget

# Get reference to the source Connection Strings
$connectionStringsSource = $webAppSource.SiteConfig.ConnectionStrings 
if($connectionStringsSource -ne $null)
{
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
    Set-AzureRmWebApp -Name $webAppTargetName -ResourceGroupName $resourceGroup -ConnectionStrings $connectionStringsTarget|Out-Null
    Write-Host "ConnectionStrings has been migrated"
}


# Get reference to the source app settings
$appSettingsSource = $webAppSource.SiteConfig.AppSettings
if($appSettingsSource -ne $null)
{
    # Create Hash variable for App Settings
    $appSettingsTarget = @{}

    # Copy over all Existing App Settings to the Hash
    ForEach ($appSettingSource in $appSettingsSource) {
        $appSettingsTarget[$appSettingSource.Name] = $appSettingSource.Value
    }

    # Save App Settings to Target
    Write-Host "Migrating App Settings from $webAppSourceName into $webAppTargetName"
    Set-AzureRmWebApp -Name $webAppTargetName -ResourceGroupName $resourceGroup -AppSettings $appSettingsTarget|Out-Null
    Write-Host "App Settings has been migrated"
}