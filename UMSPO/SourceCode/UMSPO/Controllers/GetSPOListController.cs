using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using UMSPO.Models;
using System.Xml;
using System.Text;
namespace UMSPO.Controllers
{
    public class GetSPOListController : ApiController
    {
        public HttpResponseMessage Get(string siteurl = "https://miamiedu.sharepoint.com/sites/contractsummary/", string listname = "Contract", String listview = "Contract", string Title = "Aetna", string flag = "No", string type = "P")
        {
            XmlDocument doc = new XmlDocument();
            var lstFilteredData = clsGetSPOListData.GetSPOListData(siteurl, listname, listview,Title,flag,type);
            doc.LoadXml(lstFilteredData);
            return new HttpResponseMessage() { Content = new StringContent(doc.InnerXml, Encoding.UTF8, "application/xml") };
        }
       
    }
}
