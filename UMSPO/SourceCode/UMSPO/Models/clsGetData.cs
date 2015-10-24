using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data;
using System.Data.SqlClient;
using System.Web.Script.Services;
using System.Text;
using System.Xml.Serialization;
using System.IO;
namespace UMSPO.Models
{
    public class clsGetData
    {
        static string ConvertObjectToXMLString(DataTable dt)
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
        public static string GetData(String viewname, String filter, String filterBy,string type="json")
        {

            string _Flag = string.Empty;
            SqlDataAdapter _Adapter = null;
            DataTable dtSites;
            string data = string.Empty;
            string s = "";
            List<Dictionary<string, string>> rows = new List<Dictionary<string, string>>();
            try
            {
                dtSites = new DataTable();
                StringBuilder strbuilder;
                strbuilder = new StringBuilder("");
                if (filterBy.Contains(','))
                {
                    List<string> lst = filterBy.Split(',').ToList();
                    foreach (string str in lst)
                    {
                        strbuilder.Append("CONVERT(varchar(max)," + str + ",101) LIKE '%" + filter + "%' OR ");
                    }
                }
                else
                {
                    strbuilder.Append((filterBy.ToLower() != "all" ? "CONVERT(varchar(max)," + filterBy + ",101) LIKE '%" + filter + "%'      " : filterBy.ToLower()+"    "));
                }
               
                _Adapter = new SqlDataAdapter("usp_GetData", System.Configuration.ConfigurationManager.ConnectionStrings["SPOSearchConnectionString"].ToString());
                _Adapter.SelectCommand.CommandType = CommandType.StoredProcedure;
                _Adapter.SelectCommand.CommandTimeout = 0;
                _Adapter.SelectCommand.Parameters.Add(new SqlParameter("@Searchvalue", filter != null && filter != "all" ? filter : "  "));
                _Adapter.SelectCommand.Parameters.Add(new SqlParameter("@vwname", viewname));
                _Adapter.SelectCommand.Parameters.Add(new SqlParameter("@filterby", strbuilder.ToString().Substring(0,strbuilder.ToString().Length-3).Trim()));
                _Adapter.Fill(dtSites);
              
                if (dtSites != null)
                {
                    if (type.Equals("json"))
                    {
                        System.Web.Script.Serialization.JavaScriptSerializer serializer = new System.Web.Script.Serialization.JavaScriptSerializer();

                        Dictionary<string, string> row;
                        foreach (DataRow dr in dtSites.Rows)
                        {
                            row = new Dictionary<string, string>();
                            foreach (DataColumn col in dtSites.Columns)
                            {
                                row.Add(col.ColumnName, Convert.ToString(dr[col]));
                            }
                            rows.Add(row);
                        }
                        serializer.MaxJsonLength = 2147483647;
                        data = serializer.Serialize(rows);
                    }
                    else
                    {
                        data = ConvertObjectToXMLString(dtSites);
                    }
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