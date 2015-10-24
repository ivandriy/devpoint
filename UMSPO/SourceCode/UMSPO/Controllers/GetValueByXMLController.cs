using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using UMSPO.Models;
using System.Runtime.Serialization.Json;

namespace UMSPO.Controllers
{
    public class GetValueByXMLController : ApiController
    {// GET api/<controller>
        public HttpResponseMessage Get(string O, string Filter)
        {
            string lstFilteredData = clsGetValueByXML.GetValue(O, Filter);
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