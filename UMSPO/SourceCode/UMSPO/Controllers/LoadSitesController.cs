using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using System.Text;
using System.Diagnostics;
using Microsoft.SharePoint.Client.Search;
using Microsoft.SharePoint.Client.Search.Query;
using Microsoft.SharePoint.Client;
using System.Collections;
using UMSPO.Models;
namespace UMSPO.Controllers
{
    public class LoadSitesController : ApiController
    {
        // GET api/values
        public String Title;
        public String _Url = string.Empty;
        public static String ErrorString;
        public static String ErrorMethodName;
        public static List<SPOSearchData> lstSearchData;
        public IEnumerable<WebSiteDetails> Get()
        {
            WebSiteDetails[] lstSites;
            try
            {
                LoadSitesData();

                lstSites = new WebSiteDetails[]
                     {
                         new WebSiteDetails { SiteTitle = "Done", SiteURL =string.Empty,ErrorMessage = ErrorString}
                     };
            }
            catch (Exception ex)
            {
                lstSites = new WebSiteDetails[]
                 {
                     new WebSiteDetails { SiteTitle = Title, SiteURL =_Url,ErrorMessage = ErrorMethodName+" "+ex.Message}
                 };

            }
            return lstSites;
            //return new string[] { Title, Url };
        }

        // GET api/values/5
        public string Get(int id)
        {
            return "value";
        }

        // POST api/values
        public void Post([FromBody]string value)
        {
        }

        // PUT api/values/5
        public void Put(int id, [FromBody]string value)
        {
        }

        // DELETE api/values/5
        public void Delete(int id)
        {
        }

        public static void LoadSitesData()
        {
            DateTime _StartTime;
            DateTime _EndTime;
            TimeSpan _objTime;
            string TimeTaken;
            try
            {
                ErrorString = clsSPOSearchServiceDB.InsertLogData("LoadSitesData", "Start Executing- >LoadSitesData Method", "LoadSitesData");

                if (ErrorString.ToUpper() != "TRUE")
                    return;

                //Reading the value of main site tenant url.
                Uri hostWeb = new Uri(System.Configuration.ConfigurationManager.AppSettings["HostWebUrl"]);

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


                _StartTime = DateTime.Now;
                clsSPOSearchServiceDB.InsertLogData("Deleting", "Start Deleing- >SPO FARM Type Records", "LoadSitesData");

                if (ErrorString.ToUpper() != "TRUE")
                    return;
                clsSPOSearchServiceDB.DeleteSitesData("SPO");

                if (ErrorString.ToUpper() != "TRUE")
                    return;
                clsSPOSearchServiceDB.InsertLogData("Deleting", "End Deleing- >SPO FARM Type Records", "LoadSitesData");

                if (ErrorString.ToUpper() != "TRUE")
                    return;

                _EndTime = DateTime.Now;
                _objTime = _EndTime.Subtract(_StartTime);

                TimeTaken = _objTime.Hours.ToString() + ":" + _objTime.Minutes.ToString() + ":" + _objTime.Seconds.ToString();
                clsSPOSearchServiceDB.InsertLogData("Deleting", "Delete Query Time ->" + TimeTaken, "LoadSitesData");

                if (ErrorString.ToUpper() != "TRUE")
                    return;

                _StartTime = DateTime.Now;
                //Creating the clientcontext object for Host Web Url.

                ClientContext clientContextHost = new ClientContext(hostWeb);
                clientContextHost.Credentials = onlineCredentials;

                int CurrentPage, TotalNumberOfPages, PageSize;
                CurrentPage = 1;
                TotalNumberOfPages = 1;
                PageSize = 250;
                lstSearchData = new List<SPOSearchData>();
                do
                {
                    ClientResult<ResultTableCollection> results = null;
                    try
                    {
                        results = null;
                        //Creating the search query to fetch the site collection and sub sites list.
                        KeywordQuery keywordQuery = new KeywordQuery(clientContextHost);
                        keywordQuery.QueryText = "contentclass:\"STS_Site\" contentclass:\"STS_Web\"";
                        keywordQuery.TrimDuplicates = false;

                        keywordQuery.RowLimit = PageSize;
                        keywordQuery.RowsPerPage = PageSize;

                        //int startRow = ((CurrentPage -1) * PageSize)+1;
                        int startRow = (CurrentPage - 1) * PageSize;
                        keywordQuery.StartRow = startRow;
                        //Creating aad Executing the search query
                        SearchExecutor searchExecutor = new SearchExecutor(clientContextHost);

                        results = searchExecutor.ExecuteQuery(keywordQuery);
                        clientContextHost.ExecuteQuery();
                    }
                    catch (Exception ex)
                    {
                        if (ex.InnerException == null)
                        {
                            clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->Execute Query Method->" + ex.Message, "LoadSitesData");
                        }
                        else
                        {
                            if (!string.IsNullOrEmpty(ex.InnerException.Message))
                            {
                                clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->Execute Query Method->" + ex.Message + " Inner Exception : " + ex.InnerException.Message.ToString(), "LoadSitesData");
                            }
                        }
                        //ErrorMethodName = "Error Method Name: LoadSitesData, ";

                    }

                    try
                    {
                        if (results != null)
                        {

                            if (CurrentPage == 1)
                            {
                                clsSPOSearchServiceDB.InsertLogData("Search", "Total Records- >" + results.Value[0].TotalRows.ToString(), "LoadSitesData");

                                if (ErrorString.ToUpper() != "TRUE")
                                    return;
                                TotalNumberOfPages = (int)Math.Round((double)results.Value[0].TotalRows / PageSize);
                                clsSPOSearchServiceDB.InsertLogData("Search", "Total Number of Pages- >" + TotalNumberOfPages.ToString(), "LoadSitesData");

                                if (ErrorString.ToUpper() != "TRUE")
                                    return;
                            }



                            //Excluding Personal Records from ResultSet
                            ResultTable objResultTable = results.Value[0];
                            if (objResultTable.ResultRows.Where(s => s["Path"].ToString().Contains("personal") == false).Count() > 0)
                            {
                                var lstRecords = objResultTable.ResultRows.Where(s => s["Path"].ToString().Contains("personal") == false);


                                clsSPOSearchServiceDB.InsertLogData("Search", "Total Non Personal Records- >" + lstRecords.Count().ToString(), "LoadSitesData");

                                if (ErrorString.ToUpper() != "TRUE")
                                    return;
                                //checking all the rows of search rows and exclude the personal sites.
                                //foreach (var resultRow in results.Value[0].ResultRows )
                                _StartTime = DateTime.Now;
                                //Int32 StartCounter = 0;
                                //Int32 TotalPages = 1;
                                foreach (var resultRow in lstRecords)
                                {
                                    string PathUrl = resultRow["Path"].ToString();
                                    ClientContext clientContextSite = new ClientContext(PathUrl);
                                    clientContextSite.Credentials = onlineCredentials;
                                    //Executing the method AddSiteDataIntoList to fetch the
                                    //site title, url, owners, administrators and add into the Collection list.
                                    AddSiteDataIntoCollection(PathUrl, clientContextSite);

                                }

                                //Inserting Site Data into Database table.
                                ErrorString = clsSPOSearchServiceDB.InsertSitesDataIntoDBTable(lstSearchData);

                                if (ErrorString.ToUpper() != "TRUE")
                                    return;
                            }
                        }//End of If results!=null
                    }//End of try Block
                    catch (Exception ex)
                    {
                        if (ex.InnerException == null)
                        {
                            clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->After Execute Query Method->" + ex.Message, "LoadSitesData");
                        }
                        else
                        {
                            if (!string.IsNullOrEmpty(ex.InnerException.Message))
                            {
                                clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->After Execute Query Method->" + ex.Message + " Inner Exception : " + ex.InnerException.Message.ToString(), "LoadSitesData");
                            }
                        }
                        //ErrorMethodName = "Error Method Name: LoadSitesData, ";
                    }
                    lstSearchData.Clear();
                    CurrentPage = CurrentPage + 1;
                } while (CurrentPage <= TotalNumberOfPages);



                _EndTime = DateTime.Now;
                _objTime = _EndTime.Subtract(_StartTime);

                TimeTaken = _objTime.Hours.ToString() + ":" + _objTime.Minutes.ToString() + ":" + _objTime.Seconds.ToString();
                clsSPOSearchServiceDB.InsertLogData("Search ", "Insert Contents Query Time ->" + TimeTaken, "LoadSitesData");

                if (ErrorString.ToUpper() != "TRUE")
                    return;
                clsSPOSearchServiceDB.InsertLogData("Search ", "End Executing- >LoadSitesData Method", "LoadSitesData");

                if (ErrorString.ToUpper() != "TRUE")
                    return;


            }
            catch (Exception ex)
            {
                if (ex.InnerException == null)
                {
                    clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->LoadSitesData Method->" + ex.Message, "LoadSitesData");
                }
                else
                {
                    if (!string.IsNullOrEmpty(ex.InnerException.Message))
                    {
                        clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->LoadSitesData Method->" + ex.Message + " Inner Exception : " + ex.InnerException.Message.ToString(), "LoadSitesData");
                    }
                }
                ErrorMethodName = "Error Method Name: LoadSitesData, ";

                throw ex;
            }

        }
        /// <summary>
        /// Method to fetch list of users from site having full control
        /// </summary>
        /// <param name="objSite"></param>
        /// <param name="sourceClientContext"></param>
        /// <returns></returns>
        public static List<string> GetUsersWithFullControl(Web objSite, ClientContext sourceClientContext)
        {

            //Site Owners    
            sourceClientContext.Load(objSite,
      w => w.RoleAssignments.Include(roleAssigned => roleAssigned.Member.Title,
          roleAssigned => roleAssigned.RoleDefinitionBindings.Include(roleDef => roleDef.Name))
            );

            sourceClientContext.ExecuteQuery();

            List<string> lstTitles = new List<string>();
            RoleAssignmentCollection rac = objSite.RoleAssignments;
            if (rac != null && rac.Count != 0)
            {

                foreach (RoleAssignment ra in rac)
                {
                    if (ra.RoleDefinitionBindings.Where(j => j.Name == "Full Control").FirstOrDefault() != null)
                    {
                        if (ra.Member.GetType().Name != "Group")
                        {
                            lstTitles.Add(ra.Member.Title);
                        }
                        else
                        {
                            var users = objSite.SiteGroups.GetByName(ra.Member.Title).Users;
                            sourceClientContext.Load(users);
                            sourceClientContext.ExecuteQuery();
                            foreach (var user in users)
                            {
                                lstTitles.Add(user.Title);
                            }
                        }
                    }
                }
            }
            return lstTitles;

        }
        /// <summary>
        /// Method to fetch the site title, 
        /// url, owners, administrators and add into the Collection list.
        /// </summary>
        /// <param name="SiteURL"></param>
        /// <param name="sourceClientContext"></param>

        private static void AddSiteDataIntoCollection(string SiteURL, ClientContext sourceClientContext)
        {

            //creatig variables to store the title,url, siteowners and siteadmins.
            string Title = string.Empty;
            string url = string.Empty;
            string siteOwners = string.Empty;
            string siteAdmins = string.Empty;
            List<string> lstTitles = new List<string>();
            try
            {
                if (sourceClientContext != null)
                {

                    //fetching the details of site url.
                    Web objSite = sourceClientContext.Web;
                    sourceClientContext.Load(objSite, o => o.Title, o => o.Url);
                    sourceClientContext.ExecuteQuery();
                    lstTitles = GetUsersWithFullControl(objSite, sourceClientContext);
                    //Getting Site Admins
                    UserCollection lstUserAdmins = null;

                    if (objSite.SiteUsers != null)
                    {
                        lstUserAdmins = objSite.SiteUsers;

                        sourceClientContext.Load(
                            lstUserAdmins,
                            lists => lists.Include(
                                list => list.Title,
                                list => list.Id).Where(l => l.IsSiteAdmin == true));
                    }

                    sourceClientContext.ExecuteQuery();
                    //reading the site title
                    Title = objSite.Title;

                    //reading the site URL
                    url = objSite.Url;



                    //if (lstUserCollection != null)
                    //{
                    //    lstTitles = (lstUserCollection.ToList().Select(d => d.Member.LoginName.ToString()) as IEnumerable<string>).ToList();
                    //}
                    siteOwners = string.Empty;
                    siteOwners = string.Join(";", lstTitles.Distinct());


                    //Site Administrators              
                    List<string> lstAdmins = new List<string>();
                    if (lstUserAdmins != null)
                    {
                        lstAdmins = (lstUserAdmins.ToList().Select(d => d.Title.ToString()) as IEnumerable<string>).ToList();
                    }
                    siteAdmins = string.Empty;
                    siteAdmins = string.Join(";", lstAdmins);

                    SPOSearchData objData = new SPOSearchData();
                    objData.Title = Title;
                    objData.FARM = "SPO"; ;
                    objData.SiteUrl = Uri.EscapeUriString(url); ;
                    objData.Owners = siteOwners;
                    objData.Administrators = siteAdmins;
                    objData.Remarks = "";

                    lstSearchData.Add(objData);

                }
            }
            catch (Exception ex)
            {
                string Message = ex.Message;
                string Remarks = string.Empty;
                url = SiteURL;
                if (ex.InnerException == null)
                    Remarks = " Error : " + ex.Message;
                else
                    Remarks = "Error : " + ex.Message + ", Inner Exception : " + ex.InnerException.Message;

                string comments = "Site Url : " + Uri.EscapeUriString(SiteURL) + ", " + Remarks;

                if (Message.Contains("Access denied") == true) //Handling the Accesss Denied Case
                {
                    clsSPOSearchServiceDB.InsertLogData("Error ->AddSiteDataIntoCollection", comments, "AddSiteDataIntoCollection");

                }
                else if (Message.Contains("Cannot contact site at the specified URL") == true) //Handling the Case Site not found
                {
                    clsSPOSearchServiceDB.InsertLogData("Error ->AddSiteDataIntoCollection", comments, "AddSiteDataIntoCollection");
                }
                else if (Message.Contains("The remote server returned an error: (503) Server Unavailable") == true) //Handling the Case of 503
                {
                    try
                    {
                        string sURl = SiteURL;
                        AddSiteDataIntoCollectionRetry(sURl, sourceClientContext);
                    }
                    catch (Exception exInner)
                    {
                        string InnerMessage = exInner.Message;
                        string InnerRemarks = string.Empty;
                        if (exInner.InnerException == null)
                            InnerRemarks = " Error : " + exInner.Message;
                        else
                            InnerRemarks = "Error : " + exInner.Message + ", Inner Exception : " + exInner.InnerException.Message;

                        string Innercomments = "Site Url : " + Uri.EscapeUriString(SiteURL) + ", " + InnerRemarks;

                        clsSPOSearchServiceDB.InsertLogData("Error ->AddSiteDataIntoCollection", Innercomments, "AddSiteDataIntoCollection");
                    }
                }
                else
                {

                    try
                    {

                        //fetching the details of site url.
                        Web objSite = sourceClientContext.Web;
                        sourceClientContext.Load(objSite, o => o.Title);
                        sourceClientContext.ExecuteQuery();

                        //reading the site title
                        string InnerTitle = objSite.Title;

                        SPOSearchData objData = new SPOSearchData();
                        objData.Title = InnerTitle;
                        objData.FARM = "SPO"; ;
                        objData.SiteUrl = Uri.EscapeUriString(SiteURL); ;
                        objData.Owners = siteOwners;
                        objData.Administrators = siteAdmins;
                        objData.Remarks = Remarks;
                        lstSearchData.Add(objData);


                    }
                    catch (Exception exInner)
                    {
                        string InnerMessage = exInner.Message;
                        string InnerRemarks = string.Empty;
                        if (exInner.InnerException == null)
                            InnerRemarks = " Error : " + exInner.Message;
                        else
                            InnerRemarks = "Error : " + exInner.Message + ", Inner Exception : " + exInner.InnerException.Message;

                        string Innercomments = "Site Url : " + Uri.EscapeUriString(SiteURL) + ", " + InnerRemarks;

                        clsSPOSearchServiceDB.InsertLogData("Error ->AddSiteDataIntoCollection", Innercomments, "AddSiteDataIntoCollection");
                    }


                }

            }


        }


        private static void AddSiteDataIntoCollectionRetry(string SiteURL, ClientContext sourceClientContext)
        {

            //creatig variables to store the title,url, siteowners and siteadmins.
            string Title = string.Empty;
            string url = string.Empty;
            string siteOwners = string.Empty;
            string siteAdmins = string.Empty;
            try
            {
                if (sourceClientContext != null)
                {
                    sourceClientContext.RequestTimeout = -1;
                    //fetching the details of site url.
                    Web objSite = sourceClientContext.Web;
                    sourceClientContext.Load(objSite, o => o.Title, o => o.Url);
                    sourceClientContext.ExecuteQuery();

                    //Getting Site Owners
                    // UserCollection lstUserCollection = null;
                    List<string> lstTitles = new List<string>();
                    lstTitles = GetUsersWithFullControl(objSite, sourceClientContext);
                    //if (objSite.AssociatedOwnerGroup != null)
                    //{
                    //    if (objSite.AssociatedOwnerGroup.Users != null)
                    //    {
                    //        lstUserCollection = objSite.AssociatedOwnerGroup.Users;
                    //        sourceClientContext.Load(lstUserCollection);
                    //    }
                    //}

                    //Getting Site Admins
                    UserCollection lstUserAdmins = null;

                    if (objSite.SiteUsers != null)
                    {
                        lstUserAdmins = objSite.SiteUsers;

                        sourceClientContext.Load(
                            lstUserAdmins,
                            lists => lists.Include(
                                list => list.Title,
                                list => list.Id).Where(l => l.IsSiteAdmin == true));
                    }

                    sourceClientContext.ExecuteQuery();
                    //reading the site title
                    Title = objSite.Title;

                    //reading the site URL
                    url = objSite.Url;

                    //Site Owners
                    //List<string> lstTitles = new List<string>();
                    //if (lstUserCollection != null)
                    //{
                    //    lstTitles = (lstUserCollection.ToList().Select(d => d.Title.ToString()) as IEnumerable<string>).ToList();
                    //}
                    siteOwners = string.Empty;
                    siteOwners = string.Join(";", lstTitles);


                    //Site Administrators              
                    List<string> lstAdmins = new List<string>();
                    if (lstUserAdmins != null)
                    {
                        lstAdmins = (lstUserAdmins.ToList().Select(d => d.Title.ToString()) as IEnumerable<string>).ToList();
                    }
                    siteAdmins = string.Empty;
                    siteAdmins = string.Join(";", lstAdmins);

                    SPOSearchData objData = new SPOSearchData();
                    objData.Title = Title;
                    objData.FARM = "SPO"; ;
                    objData.SiteUrl = Uri.EscapeUriString(url); ;
                    objData.Owners = siteOwners;
                    objData.Administrators = siteAdmins;
                    objData.Remarks = "";

                    lstSearchData.Add(objData);

                }
            }
            catch (Exception ex)
            {
                throw ex;

            }


        }

    }
    public class WebSiteDetails
    {

        public string SiteTitle { get; set; }
        public string SiteURL { get; set; }
        public string ErrorMessage { get; set; }

    }
}