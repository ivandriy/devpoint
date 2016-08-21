﻿Set-AzureSubscription -SubscriptionName "Visual Studio Professional with MSDN"
Select-AzureSubscription -SubscriptionName "Visual Studio Professional with MSDN" -Current -Verbose
$MossVm=Get-AzureVM -ServiceName LST-APP -Name LST-APP
$SQLVm=Get-AzureVM -ServiceName LST-DB -Name LST-DB
$DC = Get-AzureVM -ServiceName LST-DC1 -Name LST-DC1

$MossVm|Stop-AzureVM -Force
Start-Sleep -Seconds 240
$SQLVm|Stop-AzureVM -Force
Start-Sleep -Seconds 240
$DC|Stop-AzureVM -Force
Write-Host "Finished!"
Write-Host "Done!"