using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using UMSPO.Models;
using System.Xml;
using System.Runtime.Serialization.Json;
using System.Text;
namespace UMSPO.Controllers
{
    public class GetDataController : ApiController
    {
        // GET api/<controller>
        public HttpResponseMessage Get(string O, string Filter="all", String filterBy = "all")
        {
            string lstFilteredData = clsGetData.GetData(O, Filter, filterBy);
            return Request.CreateResponse(HttpStatusCode.OK, lstFilteredData, Configuration.Formatters.JsonFormatter);
        }

        // GET api/<controller>/5
        public string Get(int id)
        {
            return "value";
        }

        // POST api/<controller>
        public void Post([FromBody]string value)
        {
        }

        // PUT api/<controller>/5
        public void Put(int id, [FromBody]string value)
        {
        }

        // DELETE api/<controller>/5
        public void Delete(int id)
        {
        }
    }
}