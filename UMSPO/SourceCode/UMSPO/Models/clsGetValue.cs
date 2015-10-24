using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data;
using System.Data.SqlClient;
using System.Web.Script.Services;
namespace UMSPO.Models
{
    public class clsGetValue
    {
        public static string GetValue(String procname, String filter)
        {

            string _Flag = string.Empty;
            SqlDataAdapter _Adapter = null;
            DataTable dtSites;
            string data = string.Empty;
            try
            {
                dtSites = new DataTable();
                _Adapter = new SqlDataAdapter("usp_GetValue", System.Configuration.ConfigurationManager.ConnectionStrings["SPOSearchConnectionString"].ToString());
                _Adapter.SelectCommand.CommandType = CommandType.StoredProcedure;
                _Adapter.SelectCommand.CommandTimeout = 0;
                _Adapter.SelectCommand.Parameters.Add(new SqlParameter("@value", filter!=null?filter:"' '"));
                _Adapter.SelectCommand.Parameters.Add(new SqlParameter("@usp_procName", procname));
                _Adapter.Fill(dtSites);

                if (dtSites != null)
                {
                    System.Web.Script.Serialization.JavaScriptSerializer serializer = new System.Web.Script.Serialization.JavaScriptSerializer();
                    List<Dictionary<string, object>> rows = new List<Dictionary<string, object>>();
                    Dictionary<string, object> row;
                    foreach (DataRow dr in dtSites.Rows)
                    {
                        row = new Dictionary<string, object>();
                        foreach (DataColumn col in dtSites.Columns)
                        {
                            row.Add(col.ColumnName, dr[col]);
                        }
                        rows.Add(row);
                    }
                    data = serializer.Serialize(rows);

                }


            }
            catch (Exception ex)
            {
                _Flag = "Error in GetData:" + ex.Message;
                throw ex;
            }
            finally
            {
                if (_Adapter != null)
                {
                    _Adapter.Dispose();
                }

            }
            return data;
        }
    }
}