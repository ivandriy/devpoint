===============================================================================================================================================================================
MOSS_ExportLists.ps1

Used for export all lists information (WebURL,Title,Url,LastModified,ItemCount,Type,ItemsFilePath) from entire site collection.

Requirements:

This script must be executed on MOSS application server. 

Parameters:

 #Mandatory
-MossSiteUrl - URL of MOSS site collection, example - http://mysite

 #Optional 	
-SingleWeb - optional parameter, in case if specified - only single web is exported

Output:

Csv file named Lists.csv saved to Output folder in the script execution location - it contains all lists metadata.
This file is used as input for second script - SPO_ExportLists.ps1

Csv file named MossDocuments.csv saved to Output folder in the script execution location - it contains documents metadata such as Name,RelativeUrl,Url,Modified.

Usage:

.\MOSS_ExportLists.ps1 -MossSiteUrl http://mysite - exports all lists from site http://mysite and it's subwebs

.\MOSS_ExportLists.ps1 -MossSiteUrl http://mysite -SingleWeb - exports all lists from web http://mysite 

===============================================================================================================================================================================

SPO_ExportLists.ps1

Used to check MOSS lists migrated to O365 for missing/modified lists/documents.

Requirements:

Script requires PowerShell v.3.0 installed

Parameters:
 
  #Mandatory
-O365SiteUrl - URL of Office365 SharePoint site collection where MOSS lists were migrated. Example - https://mysite.sharepoint.com

-UserName - Office365 user name with Site Collection permissions on related O365 site collection Example - myusername@mytenant.onmicrosoft.com

-UserPassword -Office365 user password
  
  #Optional
-SingleWeb - optional parameter, in case if specified - only single SPO web is exported.

Output:

5 Csv files saved on Output folder (located in the script execution folder):
  
 ModifiedLists.csv - contains all MOSS lists founded on O365 with different ItemCount (O365 list ItemCount not equal MOSS list ItemCount)
 MissingLists.csv - contains all MOSS lists not founded on O365 (missed)
 SPODocuments.csv - contains documents metadata such as Name,RelativeUrl,Url,Modified
 MissingDocuments.csv - contains missed documents (Exist on MOSS but not found on SPO)
 ModifiedDocuments.csv - contains documents with different Modified date (MOSS Modified date not equal SPO Modified date)
 
Report.html - html page which contains information about all modified or missed lists and documents.

Usage:

.\SPO_ExportLists.ps1 -O365SiteUrl https://mysite.sharepoint.com -UserName myusername@mytenant.onmicrosoft.com -UserPassword ***** - exports all lists from site https://mysite.sharepoint.com and it's subwebs

.\SPO_ExportLists.ps1 -O365SiteUrl https://mysite.sharepoint.com -UserName myusername@mytenant.onmicrosoft.com -UserPassword ***** -SingleWeb - exports all lists from web https://mysite.sharepoint.com 