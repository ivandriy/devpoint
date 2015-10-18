param(
    [parameter(Mandatory=$true)]
    [string]$SiteUrl,

    [parameter(Mandatory=$true)]
    [string]$ListName,

    [parameter(Mandatory=$true)]
    [string]$UserName,

    [parameter(Mandatory=$true)]
    [string]$Password
)

Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking

$Dir = Split-Path -parent $MyInvocation.MyCommand.Path
$DllsDir = $Dir+"\DLL"

Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.dll" 
Add-Type –Path "$($DllsDir)\Microsoft.SharePoint.Client.Runtime.dll"

$match=$SiteUrl -match "https://\w+."
$AdminSiteUrl = ($Matches[0]).Replace(".","-admin.")+"sharepoint.com"

$Creds = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $UserName, $(convertto-securestring $Password -asplaintext -force)
$SecurePassword = New-Object System.Security.SecureString
$SecureArray = $Password.ToCharArray()
foreach ($char in $SecureArray)
{
    $SecurePassword.AppendChar($char)
}

$SPOCredentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($UserName, $SecurePassword)

Write-Host "Script starting" -BackgroundColor Black -ForegroundColor Yellow
Write-Host
Write-Host "Connecting to SPO admin service $($AdminSiteUrl)..." -ForegroundColor Yellow

try
{
    Connect-SPOService -Url $AdminSiteUrl -Credential $Creds
    Write-Host "Done!" -ForegroundColor Black -BackgroundColor Green
}
catch
{
    Write-Host "Caught an exception connection to SPO:" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
}


Write-Host "Connecting to destination site $($SiteUrl) with list $($ListName)" -ForegroundColor Yellow
try
{
    $context = New-Object Microsoft.SharePoint.Client.ClientContext($SiteUrl)  
    $context.Credentials = $SPOCredentials
    [Microsoft.SharePoint.Client.Web]$web = $context.Web
    [Microsoft.SharePoint.Client.List]$list = $web.Lists.GetByTitle($ListName)
    $context.Load($list)
    $list.EnableFolderCreation = $true
    $list.Update();
    $context.ExecuteQuery()
    Write-Host "Done!" -ForegroundColor Black -BackgroundColor Green   
}

catch
{
    Write-Host "Caught an exception while connecting to site $($SiteUrl):" -ForegroundColor Red
    Write-Host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red   
}

$countries = @('Ukraine',
                'USA',
                'England',
                'Ireland',
                'Scotland',
                'France',
                'Germany')

$cities = @('Kiev',
            'Lviv',
            'Dnipro',
            'Odessa'
            'Ternopil'
            'New-York',
            'Ostin',
            'Los-Angeless',
            'London',
            'Manchester',
            'Liverpool',
            'Dublin',
            'Paris',
            'Berlin'
)

[Object[]]$RandomData = @()
for($i=1;$i -le 10000;$i++)
{
    $obj = New-Object -TypeName PSObject
    $country = $countries|Get-Random
    $city = $cities|Get-Random
    $obj|Add-Member -MemberType NoteProperty -Name ID -Value $i
    $obj|Add-Member -MemberType NoteProperty -Name Country -Value $country
    $obj|Add-Member -MemberType NoteProperty -Name City -Value $city

    $RandomData += $obj
}

Write-Host "Creating subfolders in list $($ListName)"  -ForegroundColor Yellow
foreach ($record in $countries)
{
    # create the folder items
    [Microsoft.SharePoint.Client.ListItemCreationInformation]$newItemInfo = New-Object Microsoft.SharePoint.Client.ListItemCreationInformation
    $newItemInfo.UnderlyingObjectType = [Microsoft.SharePoint.Client.FileSystemObjectType]::Folder
    $newItemInfo.LeafName = $record.TrimEnd()
    $item = $list.AddItem($newItemInfo)
    $item["Title"] = $record.TrimEnd()
    $item.Update()
    $context.ExecuteQuery()
}


Write-Host "Deleting existing items in $($ListName)" -ForegroundColor Yellow
$continue = $true
while($continue)
{
    
    $query = [Microsoft.SharePoint.Client.CamlQuery]::CreateAllItemsQuery(100, "ID")
    $listItems = $list.GetItems( $query )
    $context.Load($listItems)
    $context.ExecuteQuery()       
    if ($listItems.Count -gt 0)
    {
        for ($i = $listItems.Count-1; $i -ge 0; $i--)
        {
            $listItems[$i].DeleteObject()
        } 
        $context.ExecuteQuery()
    }
    else
    {
        $continue = $false;
    }
}

$Records = $RandomData
Write-Host "Adding items into list $($ListName)" -ForegroundColor Yellow
foreach ($record in $Records) 
{
    [Microsoft.SharePoint.Client.ListItemCreationInformation]$itemCreateInfo = New-Object Microsoft.SharePoint.Client.ListItemCreationInformation
    $parentFolderUrl = $SiteUrl+"/Lists/"+$ListName+"/"+$record.Country
    $itemCreateInfo.FolderUrl = $parentFolderUrl
    [Microsoft.SharePoint.Client.ListItem]$item = $list.AddItem($itemCreateInfo)
    $item["Title"] = $record.ID
    $item["Country"] = $record.Country
    $item["City"] = $record.City
    $item.Update()

    $context.ExecuteQuery()
}
Write-Host "Done!" -ForegroundColor Black -BackgroundColor Green
Write-Host
Write-Host "Script finished!" -ForegroundColor Black -BackgroundColor DarkGreen