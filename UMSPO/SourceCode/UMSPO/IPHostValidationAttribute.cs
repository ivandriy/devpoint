using System;
using System.Linq;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;
using System.Net.Http;
using System.Collections.Generic;

namespace UMSPO
{
    public class IPHostValidationAttribute : System.Web.Http.Filters.ActionFilterAttribute
    {
        public override void OnActionExecuting(HttpActionContext actionContext)
        {

            var context = actionContext.Request.Properties["MS_HttpContext"] as System.Web.HttpContextBase;
            var qry = Convert.ToString(context.Request.QueryString["pwd"]) != null ? Convert.ToString(context.Request.QueryString["pwd"]) : "";
            if (context.Request.UrlReferrer != null)
            {
                if (!(context.Request.UrlReferrer.AbsoluteUri.ToLower().Contains("miamiedu") || context.Request.UrlReferrer.AbsoluteUri.ToLower().Contains("other")))
                {
                    actionContext.Response =
                  new HttpResponseMessage(System.Net.HttpStatusCode.OK)
                  {
                      Content = new StringContent("Unauthorized User")
                  };
                    return;
                }
            }
            else if (!qry.ToLower().Equals("xxxxxxxxx"))
            {
                actionContext.Response =
                  new HttpResponseMessage(System.Net.HttpStatusCode.OK)
                  {
                      Content = new StringContent("Unauthorized User")
                  };
                return;
            }

        }
    }
    //https://services.umspdev.miami.edu/help?pwd=xxxxxxxxxx

}

