#Add-AzureAccount
Set-AzureSubscription -SubscriptionName "Visual Studio Professional with MSDN" 
Select-AzureSubscription -SubscriptionName "Visual Studio Professional with MSDN" -Current 
$MossVm=Get-AzureVM -ServiceName LST-APP -Name LST-APP
$SQLVm=Get-AzureVM -ServiceName LST-DB -Name LST-DB
$DC = Get-AzureVM -ServiceName LST-DC1 -Name LST-DC1

$DC|Start-AzureVM
Start-Sleep -Seconds 600
$SQLVm|Start-AzureVM 
Start-Sleep -Seconds 300
$MossVm|Start-AzureVM
