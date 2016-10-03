using System;
using System.Collections.Generic;
using System.Configuration;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using System.Web;
using Microsoft.Owin.Security;
using Microsoft.Owin.Security.Cookies;
using Owin;
using Kentor.AuthServices.Owin;
using Kentor.AuthServices.Configuration;
using System.IdentityModel.Metadata;
using Kentor.AuthServices;


namespace SampleADFSApp
{
    public partial class Startup
    {
        private static string metaUri =
            $"https://{ConfigurationManager.AppSettings["ADFS"]}/federationmetadata/2007-06/federationmetadata.xml";
        private string entityId = $"http://{ConfigurationManager.AppSettings["ADFS"]}/adfs/services/trust";
        private string localMetaUri = ConfigurationManager.AppSettings["MetadataUri"];
        private Uri returnUrl = new Uri(ConfigurationManager.AppSettings["ReturnUrl"]);
        private string adfsType = ConfigurationManager.AppSettings["ADFSType"];
        public void ConfigureAuth(IAppBuilder app)
        {
            app.SetDefaultSignInAsAuthenticationType(CookieAuthenticationDefaults.AuthenticationType);
            app.UseCookieAuthentication(new CookieAuthenticationOptions());            
            var authServicesOptions = new KentorAuthServicesAuthenticationOptions(false)
            {
                SPOptions = new SPOptions
                {
                    EntityId = new EntityId(localMetaUri),
                    ReturnUrl = returnUrl

                },
                AuthenticationType = adfsType,
                Caption = adfsType,                
            };

            Uri metadataURI = new Uri(metaUri);
            authServicesOptions.IdentityProviders.Add(new IdentityProvider(
                    new EntityId(entityId),
                    authServicesOptions.SPOptions)
            {
                MetadataLocation = metadataURI.ToString(),
                LoadMetadata = true,                
            });
            app.UseKentorAuthServicesAuthentication(authServicesOptions);
        }
    }
}