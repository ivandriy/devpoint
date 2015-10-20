cls
#Import SharePoint Online Management Shell
Import-Module Microsoft.Online.SharePoint.Powershell -ErrorAction SilentlyContinue

Add-PSSnapIn Microsoft.SharePoint.PowerShell  -ErrorAction SilentlyContinue

#region Input Variables 

$SiteUrl = "https://xxx.sharepoint.com" #Replace the URL


$UserName = Read-Host -Prompt "Enter User Name"
$SecurePassword = Read-Host -Prompt "Enter password" -AsSecureString

$cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $UserName, $SecurePassword

#endregion

#region Connect to SharePoint Online tenant and Create Context using CSOM

Try
{
    #region Load SharePoint Client Assemblies

    Add-Type -Path "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.dll"
    Add-Type -Path "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
    Add-Type -Path "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.WorkflowServices.dll"

    #endregion


    #region connect/authenticate to SharePoint Online and get ClientContext object..    

    $clientContext = New-Object Microsoft.SharePoint.Client.ClientContext($SiteUrl) 
    $credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($UserName, $SecurePassword) 
    $clientContext.Credentials = $credentials

    Write-Host "Connected to SharePoint Online site: " $SiteUrl -ForegroundColor Green
    Write-Host ""

    #endregion


}
Catch
{
    $SPOConnectionException = $_.Exception.Message
    Write-Host ""
    Write-Host "Error:" $SPOConnectionException -ForegroundColor Red
    Write-Host ""
    Break
}

#endregion

if (!$clientContext.ServerObjectIsNull.Value) 
{ 
        $web = $clientContext.Web
        $lists = $web.Lists
        $clientContext.Load($lists);
        $clientContext.ExecuteQuery();

        $workflowServicesManager = New-Object Microsoft.SharePoint.Client.WorkflowServices.WorkflowServicesManager($clientContext, $web);
        $workflowSubscriptionService = $workflowServicesManager.GetWorkflowSubscriptionService();
        $workflowInstanceSevice = $workflowServicesManager.GetWorkflowInstanceService();



        Write-Host ""
        Write-Host "Exporting Lists" -ForegroundColor Green
        Write-Host ""

        foreach ($list in $lists)         
        {   
            $workflowSubscriptions = $workflowSubscriptionService.EnumerateSubscriptionsByList($list.Id);
            $clientContext.Load($workflowSubscriptions);                
            $clientContext.ExecuteQuery();                
            foreach($workflowSubscription in $workflowSubscriptions)
            {            
                Write-Host "**************************************************************************************"
                Write-Host "List -"$list.Title " Workflow - "$workflowSubscription.Name -ForegroundColor Green
                Write-Host "***************************************************************************************"
                Write-Host ""

                $camlQuery = New-Object Microsoft.SharePoint.Client.CamlQuery
                $camlQuery.ViewXml = "<View> <ViewFields><FieldRef Name='Title' /></ViewFields></View>";
                $listItems = $list.GetItems($camlQuery);
                $clientContext.Load($listItems);
                $clientContext.ExecuteQuery();

                foreach($listItem in $listItems)
                {
                    $workflowInstanceCollection = $workflowInstanceSevice.EnumerateInstancesForListItem($list.Id, $listItem.Id);
                    $clientContext.Load($workflowInstanceCollection);
                    $clientContext.ExecuteQuery();
                    foreach ($workflowInstance in $workflowInstanceCollection)
                    {
                       Write-Host "List Item Title:"$listItem["Title"] 
                       Write-Host "Workflow Status:"$workflowInstance.Status 
                       Write-Host "Last Updated:"$workflowInstance.LastUpdated
                       Write-Host ""
                    }
                }                   
                Write-Host ""

            }


        }  
    }                         

        #endregion