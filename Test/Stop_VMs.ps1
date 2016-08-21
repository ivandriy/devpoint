Set-AzureSubscription -SubscriptionName "Visual Studio Professional with MSDN"
Select-AzureSubscription -SubscriptionName "Visual Studio Professional with MSDN" -Current
$MossVm=Get-AzureVM -ServiceName LST-APP -Name LST-APP
$SQLVm=Get-AzureVM -ServiceName LST-DB -Name LST-DB
$DC = Get-AzureVM -ServiceName LST-DC1 -Name LST-DC1

$MossVm|Stop-AzureVM -Force
Start-Sleep -Seconds 120
$SQLVm|Stop-AzureVM -Force
Start-Sleep -Seconds 120
$DC|Stop-AzureVM -Force
Write-Host "Finished!"