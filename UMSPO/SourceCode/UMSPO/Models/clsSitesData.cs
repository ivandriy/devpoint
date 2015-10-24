using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data;
using System.Data.SqlClient;

namespace UMSPO.Models
{
    public class SitesDataInfo
    {
        #region Primitive Properties

        public int LS_ID
        {
            get;
            set;
        }

        public string LS_TITLE
        {
            get;
            set;
        }

        public string LS_FARM
        {
            get;
            set;
        }

        public string LS_SITE_URL
        {
            get;
            set;
        }

        public string LS_OWNERS
        {
            get;
            set;
        }

        public string LS_ADMINISTRATORS
        {
            get;
            set;
        }
        public string LS_REMARKS
        {
            get;
            set;
        }
        #endregion

    }

    public class clsSearchSitesServiceDB
    {

        public static List<SitesDataInfo> LoadAllSitesData(String SearachValue)
        {
            List<SitesDataInfo> lstSearchData = null;
            string _Flag = string.Empty;
            SqlDataAdapter _Adapter = null;
            DataTable dtSites;
            try
            {
                dtSites = new DataTable();
                _Adapter = new SqlDataAdapter("usp_SearchSitesData", System.Configuration.ConfigurationManager.ConnectionStrings["SPOSearchConnectionString"].ToString());
                _Adapter.SelectCommand.CommandType = CommandType.StoredProcedure;
                _Adapter.SelectCommand.CommandTimeout = 0;
                _Adapter.SelectCommand.Parameters.Add(new SqlParameter("@Searchvalue", SearachValue));
                _Adapter.Fill(dtSites);
                if (dtSites != null)
                {
                    lstSearchData = dtSites.AsEnumerable().
                                Select(site => new SitesDataInfo
                                {
                                    LS_ID = site.Field<Int32>("LS_ID"),
                                    LS_TITLE = site.Field<string>("LS_TITLE"),
                                    LS_OWNERS = site.Field<string>("LS_OWNERS"),
                                    LS_FARM = site.Field<string>("LS_FARM"),
                                    LS_SITE_URL = site.Field<string>("LS_SITE_URL"),
                                    LS_ADMINISTRATORS = site.Field<string>("LS_ADMINISTRATORS"),
                                    LS_REMARKS = site.Field<string>("LS_REMARKS")
                                }).ToList();

                }
                if (lstSearchData == null)
                {
                    lstSearchData = new List<SitesDataInfo>();
                }
            }
            catch (Exception ex)
            {
                _Flag = "Error in LoadAllSitesData:" + ex.Message;
                throw ex;
            }
            finally
            {
                if (_Adapter != null)
                {
                    _Adapter.Dispose();
                }

            }
            return lstSearchData;
        }

    }
}