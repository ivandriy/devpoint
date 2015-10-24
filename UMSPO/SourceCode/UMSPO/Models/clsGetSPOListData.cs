using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data;
using System.Data.SqlClient;
using System.Web.Script.Services;
using System.Text;
using System.Xml.Serialization;
using System.IO;
using System.Net;
using System.Net.Http;
using Microsoft.SharePoint.Client;
using UMSPO.Models;

namespace UMSPO.Models
{
    public class clsGetSPOListData
    {
       public static string ConvertObjectToXMLString(DataTable dt)
        {
            dt.TableName = "Sites";
            MemoryStream str = new MemoryStream();
            dt.WriteXml(str, true);
            str.Seek(0, SeekOrigin.Begin);
            StreamReader sr = new StreamReader(str);
            string xmlstr;
            xmlstr = sr.ReadToEnd();
            return (xmlstr);
        }
       public static string GetSPOListData(string siteurl = "https://testmiamiedu.sharepoint.com/sites/devmiri/", string listname = "Contract", String listview = "All Items", string Title = "", string flag = "No", string type = "P")
        {
            string xmldata = ""; 
            try
            {
              
                Uri hostWeb = new Uri(siteurl);

                //Reading the Login Info from config file.
                var login = type.Equals("T") ? System.Configuration.ConfigurationManager.AppSettings["UserIdT"] : System.Configuration.ConfigurationManager.AppSettings["UserId"];
                var password = type.Equals("T") ? System.Configuration.ConfigurationManager.AppSettings["PasswordT"] : System.Configuration.ConfigurationManager.AppSettings["Password"]; 


                //Securing the normall password. The text is encrypted for privacy.
                var securePassword = new System.Security.SecureString();
                foreach (char c in password)
                {
                    securePassword.AppendChar(c);
                }

                //Generate the Sharepoint credentials using username and password.
                var onlineCredentials = new SharePointOnlineCredentials(login, securePassword);
                ClientContext clientContextHost = new ClientContext(hostWeb);
                clientContextHost.Credentials = onlineCredentials;

                List oList = clientContextHost.Web.Lists.GetByTitle(listname);
                clientContextHost.Load(oList);
                clientContextHost.ExecuteQuery();
               
                View view = oList.Views.GetByTitle(listview); 

                clientContextHost.Load(view);
                clientContextHost.ExecuteQuery();
                ViewFieldCollection collField = view.ViewFields;
                clientContextHost.Load(collField);
                clientContextHost.ExecuteQuery();
               
                
                DataTable dt = new DataTable();
                dt.TableName = "TestList";
                bool isExist = false;
                var camlQuery = new CamlQuery();
                if (!Title.ToLower().Equals("all") && flag.Equals("No"))
                {
                    foreach (var myField in collField)
                    {
                        if (!(myField.ToLower().Equals("linktitle") || myField.ToLower().Equals("title")))
                        {
                            dt.Columns.Add(myField);
                        }
                        else
                        {
                            if (!isExist)
                            {
                                dt.Columns.Add("Title");
                                isExist = true;
                            }
                        }
                    }

                    camlQuery.ViewXml = "<View> <Query><Where><Eq><FieldRef Name='Title'   /><Value Type='Text' >" + Title + "</Value></Eq></Where> </Query></view>";
                }
                else
                {
                    dt.Columns.Add("Title");
                    if (!Title.ToLower().Equals("all") && flag.Equals("Yes"))
                    {
                        camlQuery.ViewXml = "<View> <Query><Where><BeginsWith><FieldRef Name='Title'   /><Value Type='Text' >" + Title + "</Value></BeginsWith></Where> </Query></view>";
                    }
                    else
                    {
                        camlQuery.ViewXml = "<View />";
                    }
                }
                ListItemCollection items = oList.GetItems(camlQuery);
                if (flag.Equals("Yes"))
                {
                    clientContextHost.Load(items, items1 => items1.Include(item1 => item1["Title"]));
                }
                else
                {
                    clientContextHost.Load(items);
                }
                clientContextHost.ExecuteQuery();
                if (!Title.ToLower().Equals("all") && flag.Equals("No"))
                {
                    foreach (ListItem li in items)
                    {
                        DataRow dr = dt.NewRow();
                        foreach (var myField in collField)
                        {
                            if (!(myField.ToLower().Equals("linktitle") || myField.ToLower().Equals("title")))
                            {
                                if (Convert.ToString(li[myField]).ToLower().Contains("fieldurlvalue"))
                                {
                                    dr[myField] = ((Microsoft.SharePoint.Client.FieldUrlValue)(li[myField])).Url;
                                }
                                else if (Convert.ToString(li[myField]).ToLower().Contains("fielduservalue"))
                                {
                                    dr[myField] = ((Microsoft.SharePoint.Client.FieldUserValue)(li[myField])).LookupValue;
                                }
                                else
                                {
                                    dr[myField] = li[myField];
                                }
                            }
                            else
                            {
                                dr["Title"] = li["Title"];
                            }

                        }
                        dt.Rows.Add(dr);
                    }
                }
                else
                {
                    foreach (ListItem li in items)
                    {
                        DataRow dr = dt.NewRow();
                        dr["Title"] = li["Title"];
                        dt.Rows.Add(dr);
                    }
                }
                DataView dv = dt.DefaultView;
                dv.Sort = "Title asc";
                DataTable sortedDT = dv.ToTable();
                xmldata = ConvertObjectToXMLString(sortedDT);            
            }
            catch (Exception ex)
            {
                try
                {
                    clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->clsGetSpoList Method->" + ex.Message , "GetSpoListData");
                }
                catch { }
                }           
            return xmldata;
        }
       public static string GetSPOListData(string siteurl = "https://testmiamiedu.sharepoint.com/sites/devmiri/", string listname = "Contract", String listview = "All Items", int Id = 1, string type = "P")
       {
           string xmldata = "";
           try
           {

               Uri hostWeb = new Uri(siteurl);

               //Reading the Login Info from config file.
               var login = type.Equals("T") ? System.Configuration.ConfigurationManager.AppSettings["UserIdT"] : System.Configuration.ConfigurationManager.AppSettings["UserId"];
               var password = type.Equals("T") ? System.Configuration.ConfigurationManager.AppSettings["PasswordT"] : System.Configuration.ConfigurationManager.AppSettings["Password"]; 

               //Securing the normall password. The text is encrypted for privacy.
               var securePassword = new System.Security.SecureString();
               foreach (char c in password)
               {
                   securePassword.AppendChar(c);
               }

               //Generate the Sharepoint credentials using username and password.
               var onlineCredentials = new SharePointOnlineCredentials(login, securePassword);
               ClientContext clientContextHost = new ClientContext(hostWeb);
               clientContextHost.Credentials = onlineCredentials;

               List oList = clientContextHost.Web.Lists.GetByTitle(listname);
               clientContextHost.Load(oList);
               clientContextHost.ExecuteQuery();

               View view = oList.Views.GetByTitle(listview);

               clientContextHost.Load(view);
               clientContextHost.ExecuteQuery();
               ViewFieldCollection collField = view.ViewFields;
               clientContextHost.Load(collField);
               clientContextHost.ExecuteQuery();


               DataTable dt = new DataTable();
               dt.TableName = "TestList";
               bool isExist = false;
               var camlQuery = new CamlQuery();
               
                   foreach (var myField in collField)
                   {
                       if (!(myField.ToLower().Equals("linktitle") || myField.ToLower().Equals("title")))
                       {
                           dt.Columns.Add(myField);
                       }
                       else
                       {
                           if (!isExist)
                           {
                               dt.Columns.Add("Title");
                               isExist = true;
                           }
                       }
                   }               
            
               ListItem li = oList.GetItemById(Id);
              
                   clientContextHost.Load(li);
              
               clientContextHost.ExecuteQuery();
              
                  // foreach (ListItem li in items)
                
                       DataRow dr = dt.NewRow();
                       foreach (var myField in collField)
                       {
                           if (!(myField.ToLower().Equals("linktitle") || myField.ToLower().Equals("title")))
                           {
                               if (Convert.ToString(li[myField]).ToLower().Contains("fieldurlvalue"))
                               {
                                   dr[myField] = ((Microsoft.SharePoint.Client.FieldUrlValue)(li[myField])).Url;
                               }
                               else if (Convert.ToString(li[myField]).ToLower().Contains("fielduservalue"))
                               {
                                   dr[myField] = ((Microsoft.SharePoint.Client.FieldUserValue)(li[myField])).LookupValue;
                               }
                               else
                               {
                                   dr[myField] = li[myField];
                               }
                           }
                           else
                           {
                               dr["Title"] = li["Title"];
                           }

                       }
                       dt.Rows.Add(dr);
                 
             
               DataView dv = dt.DefaultView;
               dv.Sort = "Title asc";
               DataTable sortedDT = dv.ToTable();
               xmldata = ConvertObjectToXMLString(sortedDT);
           }
           catch (Exception ex)
           {
               try
               {
                   clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->clsGetSpoList Method->" + ex.Message, "GetSpoListData");
               }
               catch { }
           }
           return xmldata;
       }
    }
}