using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data;
using System.Data.SqlClient;
using UMSPO.Models;
using System.IO;

namespace UMSPO.Models
{
    public class clsGetValueByXML
    {
        public static string ConvertObjectToXMLString(DataTable dt)
        {
            dt.TableName = "Sites";
            MemoryStream str = new MemoryStream();
            dt.WriteXml(str, true);
            str.Seek(0, SeekOrigin.Begin);
            StreamReader sr = new StreamReader(str);
            string xmlstr;
            xmlstr = sr.ReadToEnd();
            return (xmlstr);
        }
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
                _Adapter.SelectCommand.Parameters.Add(new SqlParameter("@value", filter != null ? filter : "' '"));
                _Adapter.SelectCommand.Parameters.Add(new SqlParameter("@usp_procName", procname));
                _Adapter.Fill(dtSites);
                if (dtSites != null)
                {
                    data =Convert.ToString(dtSites.Rows[0][0]);
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