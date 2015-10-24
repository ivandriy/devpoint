using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using UMSPO.Models;
namespace UMSPO.Controllers
{
    public class EventLogController : ApiController
    {
        // GET api/EventLog
        public string Get()
        {
            string _Message = "get Method called";
            //if (!string.IsNullOrEmpty(EventName))
            //{
            //    _Message = clsEventLogMasterDB.InsertEventLogMasterData(EventName, EventValue);
                
            //}
            //else
            //    _Message = "Event name cannot be blank.";
            clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->After Execute Query Method->", "SecureItem");
            return _Message;
        }

        // GET api/EventLog/5
        public string Get(int id)
        {
            return "value";
        }

        // POST api/EventLog
        public void Post(EventMasterData objEventDetails)
        {
            if (!string.IsNullOrEmpty(objEventDetails.EventLogName))
            {
                try
                {
                    clsEventLogMasterDB.InsertEventLogMasterData(objEventDetails);
                }
                catch (Exception ex)
                {
                    clsSPOSearchServiceDB.InsertLogData("Error", "Error occurred in ->After Execute Query Method->" + ex.Message, "SecureItem");
                }

            }
        }

        // PUT api/EventLog/5
        public void Put(int id, [FromBody]string value)
        {
        }

        // DELETE api/EventLog/5
        public void Delete(int id)
        {
        }
    }
}
