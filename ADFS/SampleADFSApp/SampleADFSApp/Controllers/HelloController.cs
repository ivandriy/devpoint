using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace SampleADFSApp.Controllers
{
    
    public class HelloController : ApiController
    {
        public HttpResponseMessage Get()
        {
            return Request.CreateResponse(HttpStatusCode.OK, "Hello", Configuration.Formatters.JsonFormatter);
        }
    }
}
