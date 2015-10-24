using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using UMSPO.Models;
namespace UMSPO.Controllers
{
    public class SearchValuesController : ApiController
    {
        // GET api/searchsites
        public HttpResponseMessage Get(string SearchData)
        {

            List<SitesDataInfo> lstFilteredData = null;
            lstFilteredData = clsSearchSitesServiceDB.LoadAllSitesData(SearchData);
            if (lstFilteredData == null)
            {
                lstFilteredData = new List<SitesDataInfo>();
            }
            //List<SitesDataInfo> lstFilteredDataNew = new List<SitesDataInfo>();

            //foreach (SitesDataInfo objData in lstFilteredData)
            //{


            //    lstFilteredDataNew.Add(new SitesDataInfo { LS_ID = objData.LS_ID, LS_TITLE = objData.LS_TITLE, LS_FARM = objData.LS_FARM, LS_SITE_URL = objData.LS_SITE_URL, LS_OWNERS = objData.LS_OWNERS, LS_ADMINISTRATORS = objData.LS_ADMINISTRATORS });
            //}
            return Request.CreateResponse<IEnumerable<SitesDataInfo>>(HttpStatusCode.OK, lstFilteredData); ;
        }

        // GET api/searchsites/5
        public string Get(int id)
        {
            return "value";
        }

        // POST api/searchsites
        public void Post([FromBody]string value)
        {
        }

        // PUT api/searchsites/5
        public void Put(int id, [FromBody]string value)
        {
        }

        // DELETE api/searchsites/5
        public void Delete(int id)
        {
        }
    }
}
