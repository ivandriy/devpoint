using System;
using System.Web.Mvc;
using System.Web.Routing;

namespace UMSPO
{
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
    public class NoDirectAccessAttribute : ActionFilterAttribute
    {
       
        public override void OnActionExecuting(ActionExecutingContext filterContext)
        {

            filterContext.HttpContext.Session["pwd"] = filterContext.HttpContext.Session["pwd"] == null ? (Convert.ToString(filterContext.HttpContext.Request.QueryString["pwd"]) != null ? Convert.ToString(filterContext.HttpContext.Request.QueryString["pwd"]) : "") : filterContext.HttpContext.Session["pwd"];

            if (!(Convert.ToString(filterContext.HttpContext.Session["pwd"]).ToLower().Equals("onlyum") || !string.IsNullOrEmpty(Convert.ToString(filterContext.HttpContext.Session["pwd"]))))
            {
                filterContext.Result = new RedirectToRouteResult(new
                          RouteValueDictionary(new { controller = "Home", action = "Index", area = "" }));
            }
           
        }
    }
}