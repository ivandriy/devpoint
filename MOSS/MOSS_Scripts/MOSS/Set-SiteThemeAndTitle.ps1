<# 
    Script changes site theme and updates site title

    Usage:

    .\Set-SiteThemeAndTitle.ps1 -Url http://moss -Theme Simple
    Sets http://moss site theme to "Simple"

    .\Set-SiteThemeAndTitle.ps1 -Url http://moss -Title NewTitle
    Set http://moss site title to "NewTitle"
#>


param(
[parameter(Mandatory=$true)]
[string]$Url,
[string]$Theme,
[string]$Title
)

[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")


function Get-SPSite([string]$url) {

	New-Object Microsoft.SharePoint.SPSite($url)
}

function Get-SPWeb([string]$url) {

	$SPSite = Get-SPSite $url
	$SPSite.OpenWeb()
}

function Set-SPTheme([string]$url, [string]$Theme) {

	$OpenWeb = Get-SPWeb $url
	$OpenWeb.ApplyTheme($Theme)
	$OpenWeb.Dispose()
}

function Set-SPTitle([string]$url, [string]$Title) {
    $OpenWeb = Get-SPWeb $url
    $OpenWeb.Title = $Title
    $OpenWeb.Update()
    $OpenWeb.Dispose()
}


if($Theme) 
{
    Write-Host "Applying theme $($Theme) at site - $($Url)..." 
    Set-SPTheme -url $url -Theme $Theme
    Write-Host "Done!" 
}
elseif($Title)
{
    Write-Host "Applying new title --[$($Title)]-- at site - $($Url)..." 
    Set-SPTitle -url $url -Title $Title
    Write-Host "Done!"
}