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
    public class GetDataByXmlController : ApiController
    {
        public HttpResponseMessage Get(string O, string Filter="all", String filterBy = "all")
        {
            XmlDocument doc = new XmlDocument();
            var lstFilteredData = clsGetData.GetData(O, Filter, filterBy,"xml");
            doc.LoadXml(lstFilteredData);
            return new HttpResponseMessage() { Content = new StringContent(doc.InnerXml, Encoding.UTF8, "application/xml") };
        }
    }
}
