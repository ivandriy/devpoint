using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security;
using System.Text;
using System.Threading.Tasks;
using Microsoft.SharePoint.Client;

namespace SPOCustomTheme
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("******Applying customization on SPO*********");
            string siteUrl = GetSite();
            Console.WriteLine("Enter credentials for site: {0}", siteUrl);
            string userName = GetUserName();
            SecureString password = GetPassword();            
            /* End Program if no Credentials */
            if (string.IsNullOrEmpty(userName) || (password == null))
                return;
            try
            {
                ClientContext context = new ClientContext(siteUrl);
                context.AuthenticationMode = ClientAuthenticationMode.Default;
                context.Credentials = new SharePointOnlineCredentials(userName, password);
                Web web = context.Web;
                context.Load(web);
                context.ExecuteQuery();
                var isLoadEnabled = AppCatalog.IsAppSideloadingEnabled(context).Value;
                context.ExecuteQuery();                
                if (!isLoadEnabled)
                    EnableSideLoading(context);                                      
                string logoPath = Path.Combine((Directory.GetParent(AppDomain.CurrentDomain.BaseDirectory).Parent).Parent.FullName, "Resources/CustomTheme/logo.png");
                string cssPath = Path.Combine((Directory.GetParent(AppDomain.CurrentDomain.BaseDirectory).Parent).Parent.FullName, "Resources/CustomTheme/CustomTheme.css");
                string jsPath = Path.Combine((Directory.GetParent(AppDomain.CurrentDomain.BaseDirectory).Parent).Parent.FullName, "Resources/CustomTheme/CustomTheme.js");                                                
                //Upload files
                UploadFilesToAssetsFolder(context, web, logoPath);
                UploadFilesToAssetsFolder(context, web, cssPath);
                UploadFilesToAssetsFolder(context, web, jsPath);                
                //Clean up before start
                //RemoveAllUserActions(context,web);
                //Add custom JS file                
                InjectJsFile(context, web, "CustomTheme.js",100);
                //Add custom CSS
                InjectCssFileIntoHead(context, web, "CustomTheme.css", 200);                           
                //Apply custom logo                
                web.SiteLogoUrl = web.ServerRelativeUrl + "/SiteAssets/logo.png";
                //Apply alternate CSS
                //web.AlternateCssUrl = web.ServerRelativeUrl + "/SiteAssets/CustomTheme.css";
                web.Update();
                web.Context.ExecuteQuery();
            }
            catch (Exception e)
            {

                Console.WriteLine(e.Message);
                Console.WriteLine(e.StackTrace);
                Console.WriteLine(e.TargetSite);
            }
           
            Console.WriteLine("Changes applied successfully.");
            Console.WriteLine("Press any key to continue.");
            Console.Read();

        }

        private static void EnableSideLoading(ClientContext context)
        {
            try
            {
                Site site = context.Site;
                var sideLoadingGuid = new Guid("AE3A1339-61F5-4f8f-81A7-ABD2DA956A7D");
                site.Features.Add(sideLoadingGuid, false, FeatureDefinitionScope.None);
                context.ExecuteQuery();
            }
            catch (ServerException e)
            {                                               
            }                           
        }

        private static void RemoveAllUserActions(ClientContext context, Web web)
        {            
            var existingActions = web.UserCustomActions;
            context.Load(existingActions);
            context.ExecuteQuery();
            var actions = existingActions.ToArray();
            foreach (var existingAction in actions)
            {
                    if(existingAction.Location == "ScriptLink")
                        existingAction.DeleteObject();
            }
            context.ExecuteQuery();
        }

        private static void InjectCssFileIntoHead(ClientContext context, Web web,string filename,int sequence)
        {                        
            var existingActions = web.UserCustomActions;            
            context.Load(existingActions);
            context.ExecuteQuery();
            var actions = existingActions.ToArray();
            foreach (var existingAction in actions)
            {
                if (existingAction.Description == filename
                    && existingAction.Location == "ScriptLink")
                {
                    existingAction.DeleteObject();                    
                }                    
            }
            context.ExecuteQuery();
            List assetsLibrary = web.Lists.GetByTitle("Site Assets");
            web.Context.Load(assetsLibrary, l => l.RootFolder);
            context.ExecuteQuery();
            string filePath = assetsLibrary.RootFolder.ServerRelativeUrl +@"/"+filename;
            Microsoft.SharePoint.Client.File cssFile;
            if (TryGetFileByServerRelativeUrl(context, web, filePath, out cssFile))
            {
                string revision = Guid.NewGuid().ToString().Replace("-", "");
                string fileLink = string.Format("{0}?rev={1}", filePath, revision);
                StringBuilder links = new StringBuilder(@"
                newLink = document.createElement('link');");
                links.AppendFormat(@"
                newLink.rel = 'stylesheet'
                newLink.type = 'text/css'
                newLink.href = '{0}' 
                headID.appendChild(newLink);", fileLink);
                string scriptBlock = links.ToString();
                UserCustomAction cssAction = web.UserCustomActions.Add();
                cssAction.Location = "ScriptLink";
                cssAction.Sequence = sequence;
                cssAction.ScriptBlock = scriptBlock;
                cssAction.Name = filename;
                cssAction.Update();
                context.Load(web, s => s.UserCustomActions);
                context.ExecuteQuery();
            }
            else
            {
                Console.WriteLine("File: {0} is not exist",filePath);
                return;
            }            
         }

        private static void RemoveInjectedFile(ClientContext context, Web web,string filename)
        {
            var existingActions = web.UserCustomActions;
            context.Load(existingActions);
            context.ExecuteQuery();
            var actions = existingActions.ToArray();
            foreach (var existingAction in actions)
            {
                if (existingAction.Description == filename
                    && existingAction.Location == "ScriptLink")
                    existingAction.DeleteObject();
            }
            context.ExecuteQuery();
        }
        
        private static void InjectJsFile(ClientContext context,Web web, string filename, int sequence)
        {
            List assetsLibrary = web.Lists.GetByTitle("Site Assets");
            web.Context.Load(assetsLibrary, l => l.RootFolder);
            context.ExecuteQuery();
            string filePath = assetsLibrary.RootFolder.ServerRelativeUrl + @"/" + filename;
            string revision = Guid.NewGuid().ToString().Replace("-", "");
            string jsLink = string.Format("{0}?rev={1}", filePath, revision);
            StringBuilder scripts = new StringBuilder(@"
                var headID = document.getElementsByTagName('head')[0]; 
                var");
            scripts.AppendFormat(@"
                newScript = document.createElement('script');
                newScript.type = 'text/javascript';
                newScript.src = '{0}';
                headID.appendChild(newScript);", jsLink);
            string scriptBlock = scripts.ToString();
            var existingActions = web.UserCustomActions;
            context.Load(existingActions);
            context.ExecuteQuery();
            var actions = existingActions.ToArray();
            foreach (var action in actions)
            {
                if (action.Description == filename &&
                    action.Location == "ScriptLink")
                {
                    action.DeleteObject();
                    
                }
            }
            context.ExecuteQuery();
            var newAction = existingActions.Add();
            newAction.Description = filename;
            newAction.Location = "ScriptLink";
            newAction.ScriptBlock = scriptBlock;
            newAction.Sequence = sequence;
            newAction.Update();
            context.Load(web, s => s.UserCustomActions);
            context.ExecuteQuery();
        }

        private static void UploadFilesToAssetsFolder(ClientContext context,Web web, string filePath)
        {
            // Instance to site assets
            List assetsLibrary = web.Lists.GetByTitle("Site Assets");
            web.Context.Load(assetsLibrary,l=>l.RootFolder);            
            FileCreationInformation newFile = new FileCreationInformation();
            // Use CSOM to upload the file in
            newFile = new FileCreationInformation();
            try
            {
                newFile.Content = System.IO.File.ReadAllBytes(filePath);
            }
            catch (System.IO.FileNotFoundException ex)
            {

                Console.WriteLine("Exception while loading file {0}: {1}",filePath,ex.Message);
            }
            
            newFile.Url = Path.GetFileName(filePath);
            newFile.Overwrite = true;
            Microsoft.SharePoint.Client.File uploadFile = assetsLibrary.RootFolder.Files.Add(newFile);
            uploadFile = assetsLibrary.RootFolder.Files.Add(newFile);
            web.Context.Load(uploadFile);
            web.Context.ExecuteQuery();
        }

        private static SecureString GetPassword()
        {
            SecureString securePwd = new SecureString();
            try
            {
                Console.WriteLine("SPO Password: ");
                for (ConsoleKeyInfo keyInfo = Console.ReadKey(true); keyInfo.Key != ConsoleKey.Enter;keyInfo = Console.ReadKey(true))
                {
                    if (keyInfo.Key == ConsoleKey.Backspace)
                    {
                        if (securePwd.Length > 0)
                        {
                            securePwd.RemoveAt(securePwd.Length-1);
                            Console.SetCursorPosition(Console.CursorLeft - 1, Console.CursorTop);
                            Console.Write(" ");
                            Console.SetCursorPosition(Console.CursorLeft - 1, Console.CursorTop);
                        }
                    }
                    else if (keyInfo.Key != ConsoleKey.Enter)
                    {
                        Console.Write("*");
                        securePwd.AppendChar(keyInfo.KeyChar);
                    }
                    
                }
                Console.WriteLine("");
            }
            catch (Exception e)
            {
                securePwd = null;
                Console.WriteLine(e.Message);                
            }
            return securePwd;
        }

        private static string GetUserName()
        {
            string strUserName = string.Empty;
            try
            {
                Console.WriteLine("SPO user name:");
                strUserName = Console.ReadLine();

            }
            catch (Exception e)
            {

                Console.WriteLine(e.Message);
                strUserName = string.Empty;
            }
            return strUserName;
        }

        private static string GetSite()
        {
            string siteUrl = string.Empty;
            try
            {
                Console.WriteLine("Please enter your site Url:");
                siteUrl = Console.ReadLine();

            }
            catch (Exception e)
            {

                Console.WriteLine(e.Message);
                siteUrl = string.Empty;
            }
            return siteUrl;
        }

        public static bool TryGetFileByServerRelativeUrl(ClientContext context, Web web, string serverRelativeUrl, out Microsoft.SharePoint.Client.File file)
        {            
            try
            {
                file = web.GetFileByServerRelativeUrl(serverRelativeUrl);
                context.Load(file);
                context.ExecuteQuery();
                return true;
            }
            catch (Microsoft.SharePoint.Client.ServerException ex)
            {
                if (ex.ServerErrorTypeName == "System.IO.FileNotFoundException")
                {
                    file = null;
                    return false;
                }
                else
                    throw;
            }
        }

    }
}
