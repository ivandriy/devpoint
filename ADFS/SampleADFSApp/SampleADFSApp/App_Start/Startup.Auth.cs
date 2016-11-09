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
using System.Security.Cryptography.X509Certificates;
using System.Web.Hosting;
using Kentor.AuthServices;
using Kentor.AuthServices.WebSso;


namespace SampleADFSApp
{
    public partial class Startup
    {
        private static string metaUri =
            $"https://{ConfigurationManager.AppSettings["ADFS"]}/federationmetadata/2007-06/federationmetadata.xml";
        private static string entityId = $"http://{ConfigurationManager.AppSettings["ADFS"]}/adfs/services/trust";
        private static string localMetaUri = ConfigurationManager.AppSettings["MetadataUri"];
        private static Uri returnUrl = new Uri(ConfigurationManager.AppSettings["ReturnUrl"]);
        private string adfsType = ConfigurationManager.AppSettings["ADFSType"];
        public void ConfigureAuth(IAppBuilder app)
        {
            app.SetDefaultSignInAsAuthenticationType(CookieAuthenticationDefaults.AuthenticationType);
            app.UseCookieAuthentication(new CookieAuthenticationOptions());            
            var authServicesOptions = new KentorAuthServicesAuthenticationOptions(false)
            {
                SPOptions = CreateSPOptions()
                //SPOptions = new SPOptions
                //{
                //    EntityId = new EntityId(localMetaUri),
                //    ReturnUrl = returnUrl,
                //    WantAssertionsSigned = true
                //},
                //AuthenticationType = adfsType,
                //Caption = adfsType,                            
            };            
            Uri metadataURI = new Uri(metaUri);
            var idp = new IdentityProvider(new EntityId(entityId), authServicesOptions.SPOptions)
            {
                AllowUnsolicitedAuthnResponse = true,
                Binding = Saml2BindingType.HttpRedirect,
                MetadataLocation = metadataURI.ToString(),
                LoadMetadata = true                
            };
            //idp.SigningKeys.AddConfiguredKey(
            //    new X509Certificate2(
            //        HostingEnvironment.MapPath(
            //            "~/App_Data/AzureApp_signing.cer")));

            authServicesOptions.IdentityProviders.Add(idp);
            app.UseKentorAuthServicesAuthentication(authServicesOptions);
        }

        private static SPOptions CreateSPOptions()
        { 
            var spOptions = new SPOptions
            {
                EntityId = new EntityId(localMetaUri),
                ReturnUrl = returnUrl,
                WantAssertionsSigned = true
            };
            spOptions.ServiceCertificates.Add(new X509Certificate2(
                AppDomain.CurrentDomain.SetupInformation.ApplicationBase + "/App_Data/AzureApp_private_sha256.pfx","nomad_is_1593*"));

            return spOptions;
        }
    }
}