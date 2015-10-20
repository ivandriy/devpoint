$MossVm=Get-AzureVM -ServiceName LST-APP -Name LST-APP
$SQLVm=Get-AzureVM -ServiceName LST-DB -Name LST-DB

$MossVm|Stop-AzureVM -StayProvisioned
$SQLVm|Stop-AzureVM -StayProvisioned 

$MossVmDisk=$MossVm|Get-AzureOSDisk
$SQLVmDisk=$SQLVm|Get-AzureOSDisk

$StorageAccountName=$MossVmDisk.MediaLink.Host.Split('.')[0]
Set-AzureSubscription -SubscriptionName "Visual Studio Professional with MSDN" -CurrentStorageAccountName $StorageAccountName
$backupsContainer="backups"
New-AzureStorageContainer -Name $backupsContainer -Permission Off

$MossVmDiskBlob=$MossVmDisk.MediaLink.Segments[-1]
$SQLVmDiskBlob=$SQLVmDisk.MediaLink.Segments[-1]
$VmDiskContainer=$MossVmDisk.MediaLink.Segments[-2].Split('/')[0]
Start-AzureStorageBlobCopy -SrcContainer $VmDiskContainer -SrcBlob $MossVmDiskBlob -DestContainer $backupsContainer
Start-AzureStorageBlobCopy -SrcContainer $VmDiskContainer -SrcBlob $SQLVmDiskBlob -DestContainer $backupsContainer

Get-AzureStorageBlobCopyState -Container $backupsContainer -Blob $SQLVmDiskBlob -WaitForComplete
Get-AzureStorageBlob -Container $backupsContainer

$SQLVm|Start-AzureVM
$MossVm|Start-AzureVM
