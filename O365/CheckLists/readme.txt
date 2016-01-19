===============================================================================================================================================================================
MOSS_ExportLists.ps1

Used for export all lists information (WebURL,Title,Url,LastModified,ItemCount,Type,ItemsFilePath) from entire site collection.

Requirements:

This script must be executed on MOSS application server. 

Parameters:

-MossSiteUrl - URL of MOSS site collection, example - http://mysite

-AllSubWebs - optional parameter, in case if specified - export will go through all subwebs under MOSS site. If not specified - only root web is exported

Output:

Csv file (Lists.csv) saved to Output folder in the script execution location - it contains all lists metadata.
This file is used as input for second script - SPO_ExportLists.ps1

Csv files saved in Output subfolder named MOSS_Libraries - each of them contains document library items (documents) metadata such as Name,RelativeUrl,Url,Modified.
Files name format is next:

<SiteCollectionName>_<DocumentLibraryTitle>.csv


Usage:

.\MOSS_ExportLists.ps1 -MossSiteUrl http://mysite - exports all lists from site http://mysite

.\MOSS_ExportLists.ps1 -MossSiteUrl http://mysite -AllSubWebs - exports all lists from site http://mysite and it's subwebs

===============================================================================================================================================================================

SPO_ExportLists.ps1

Used to check MOSS lists migrated to O365 for missing/modified lists/documents.

Requirements:

Script requires PowerShell v.3.0 installed

Parameters:

-O365SiteUrl - URL of Office365 SharePoint site collection where MOSS lists were migrated. Example - https://mysite.sharepoint.com

-UserName - Office365 user name with Site Collection permissions on related O365 site collection Example - myusername@mytenant.onmicrosoft.com

-UserPassword -Office365 user password

-AllSubWebs - optional parameter, in case if specified - export will go through all subwebs under SPO site. If not specified - only root web is exported.

Output:

4 Csv files saved on Output folder (located in the script execution folder):
  
 ModifiedLists.csv - contains all MOSS lists founded on O365 with different ItemCount (O365 list ItemCount not equal MOSS list ItemCount)
 MissingLists.csv - contains all MOSS lists not founded on O365 (missed)
 MissingDocuments.csv - contains missed documents (Exist on MOSS but not found on SPO)
 ModifiedDocuments.csv - contains documents with different Modified date (MOSS Modified date not equal SPO Modified date)
 
Csv files saved in Output folder subfolder named SPO_Libraries in - each of them contains document library items (documents) metadata such as Name,RelativeUrl,Url,Modified.
Files name format is next:

<SiteCollectionName>_<DocumentLibraryTitle>.csv 

Report.html - html page which contains information about all modified or missed lists and documents.

Usage:

.\SPO_ExportLists.ps1 -O365SiteUrl https://mysite.sharepoint.com -UserName myusername@mytenant.onmicrosoft.com -UserPassword ***** - exports all lists from site https://mysite.sharepoint.com

.\SPO_ExportLists.ps1 -O365SiteUrl https://mysite.sharepoint.com -UserName myusername@mytenant.onmicrosoft.com -UserPassword ***** -AllSubWebs - exports all lists from site https://mysite.sharepoint.com and it's subwebs