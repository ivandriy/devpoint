using Microsoft.SharePoint.Client;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using UMSPO.Models;
namespace UMSPO.Controllers
{
    public class SecureItem
    {
       public int id { get; set; }
       public string listname { get; set; }
       public string url { get; set; }
    }
    public class SecureItemController : ApiController
    {
        public string Get()
        {
            string _Message = "get Method called";
            //if (!string.IsNullOrEmpty(EventName))
            //{
            //    _Message = clsEventLogMasterDB.InsertEventLogMasterData(EventName, EventValue);

            //}
            //else
            //    _Message = "Event name cannot be blank.";

            return _Message;
        }

        // POST api/EventLog
        public string Post(SecureItem item)
        {
            SecureItem(item.id, item.listname,item.url);
            return "";
        }
        public static void SecureItem(int id, string listname, string url)
        {

            try
            {

                //Reading the value of main site tenant url.
                //Uri hostWeb = new Uri(System.Configuration.ConfigurationManager.AppSettings["HostWebUrl"]);
                Uri hostWeb = new Uri(url);

                //Reading the Login Info from config file.
                var login = System.Configuration.ConfigurationManager.AppSettings["UserId"];
                var password = System.Configuration.ConfigurationManager.AppSettings["Password"];

                //Securing the normall password. The text is encrypted for privacy.
                var securePassword = new System.Security.SecureString();
                foreach (char c in password)
                {
                    securePassword.AppendChar(c);
                }

                //Generate the Shaepoint credentials using username and password.
                var onlineCredentials = new SharePointOnlineCredentials(login, securePassword);
                ClientContext clientContext = new ClientContext(hostWeb);
                clientContext.Credentials = onlineCredentials;
                Web site = clientContext.Web;
                List list = clientContext.Web.Lists.GetByTitle(listname);
                ListItem item = list.GetItemById(id);
                item.BreakRoleInheritance(true, false);
                clientContext.Load(site, s => s.RoleDefinitions);
                clientContext.ExecuteQuery();
                clientContext.Load(item, l => l.HasUniqueRoleAssignments);

                clientContext.ExecuteQuery();
                RoleDefinition role = null;
                List<Principal> groupsToRemove = new List<Principal>();
                if (item.HasUniqueRoleAssignments)
                {
                    role = site.RoleDefinitions.GetByName("Full Control");
                    clientContext.Load(role);
                    clientContext.ExecuteQuery();
                    RoleAssignmentCollection oRoleAssignments = item.RoleAssignments;
                    clientContext.Load(oRoleAssignments);
                    clientContext.ExecuteQuery();
                    List<RoleDefinition> rolesToRemove = new List<RoleDefinition>();
                    foreach (RoleAssignment oRoleAssignment in oRoleAssignments)
                    {
                        clientContext.Load(oRoleAssignment, r => r.Member, r => r.RoleDefinitionBindings);
                        clientContext.ExecuteQuery();
                        Principal oPrincipal = oRoleAssignment.Member;
                        //if (oPrincipal.PrincipalType == Microsoft.SharePoint.Client.Utilities.PrincipalType.SharePointGroup)
                        //{
                        int roleDefCount = 0;
                        foreach (RoleDefinition def in oRoleAssignment.RoleDefinitionBindings)
                        {
                            if (def.Id == role.Id)
                            {
                                //item.RoleAssignments.Add(site.CurrentUser, oRoleAssignment.RoleDefinitionBindings);
                                break;
                            }
                            else
                            {
                                roleDefCount++;
                                if (roleDefCount == oRoleAssignment.RoleDefinitionBindings.Count)
                                    groupsToRemove.Add(oPrincipal);
                            }
                        }
                        //}
                    }

                    foreach (Principal group in groupsToRemove)
                    {
                        item.RoleAssignments.GetByPrincipal(group).DeleteObject();
                    }

                    item.Update();
                    list.Update();
                }
                clientContext.ExecuteQuery();

                RoleDefinitionBindingCollection collRoleDefinitionBinding = new RoleDefinitionBindingCollection(clientContext);

                collRoleDefinitionBinding.Add(clientContext.Web.RoleDefinitions.GetByType(RoleType.Administrator)); //Set permission type

                item.RoleAssignments.Add(site.CurrentUser, collRoleDefinitionBinding); //oGroup - your SPGroup

                clientContext.ExecuteQuery();
            }
            catch (Exception ex) 
            {
                clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->After Execute Query Method->" + ex.Message, "SecureItem");
            }
        }
    }
}
