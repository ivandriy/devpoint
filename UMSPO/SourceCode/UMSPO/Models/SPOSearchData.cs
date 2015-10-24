using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data;
using System.Data.SqlClient;
namespace UMSPO.Models
{
    public class SPOSearchData
    {
        public string Title { get; set; }
        public string FARM { get; set; }
        public string SiteUrl { get; set; }
        public string Owners { get; set; }
        public string Administrators { get; set; }
        public string Remarks { get; set; }
    }

    public class clsSPOSearchServiceDB
    {
        public static string   InsertSitesDataIntoDBTable(List<SPOSearchData> lstSearchData)
        {
            SqlConnection con = null;
            SqlCommand cmd = null;
            string _Flag = string.Empty;
            try
            {
                con = new SqlConnection(System.Configuration.ConfigurationManager.ConnectionStrings["SPOSearchConnectionString"].ToString());
                if (con.State == ConnectionState.Closed)
                    con.Open();

                cmd = new SqlCommand("usp_InsertSitesData", con);

                cmd.CommandTimeout = 0;
                cmd.CommandType = CommandType.StoredProcedure;



                foreach (SPOSearchData objData in lstSearchData)
                {
                    cmd.Parameters.Clear();
                    cmd.Parameters.Add(new SqlParameter("@LS_TITLE", objData.Title));
                    cmd.Parameters.Add(new SqlParameter("@LS_FARM", objData.FARM));
                    cmd.Parameters.Add(new SqlParameter("@LS_SITE_URL", objData.SiteUrl));
                    cmd.Parameters.Add(new SqlParameter("@LS_OWNERS", objData.Owners));
                    cmd.Parameters.Add(new SqlParameter("@LS_ADMINISTRATORS", objData.Administrators));
                    cmd.Parameters.Add(new SqlParameter("@LS_REMARKS", objData.Remarks));

                    cmd.ExecuteNonQuery();
                }

                _Flag = "True";
            }

            catch (Exception ex)
            {
                _Flag = "Error in InsertSitesDataIntoDBTable:" +ex.Message;
                throw ex;
            }
            finally
            {
                if (con.State == ConnectionState.Open)

                    con.Close();
                if (cmd != null)
                {
                    cmd.Dispose(); 
                }
                if (con != null)
                    con.Dispose(); 
            }
            return _Flag;
        }

        public static string  InsertLogData(string LogAction ,string LogDescription,string Method)
        {
            SqlConnection con = null;
            SqlCommand cmd = null;
            string _Flag = string.Empty;
            try
            {
                con = new SqlConnection(System.Configuration.ConfigurationManager.ConnectionStrings["SPOSearchConnectionString"].ToString());
                if (con.State == ConnectionState.Closed)
                    con.Open();

                cmd = new SqlCommand("usp_InsertLogsData", con);

                cmd.CommandTimeout = 0;
                cmd.CommandType = CommandType.StoredProcedure;



             
                    cmd.Parameters.Clear();
                    cmd.Parameters.Add(new SqlParameter("@LOG_ACTION", LogAction));
                    cmd.Parameters.Add(new SqlParameter("@LOG_DESCRIPTION", LogDescription));
                    cmd.Parameters.Add(new SqlParameter("@LOG_METHOD", Method));

                    cmd.ExecuteNonQuery();
               

                _Flag = "True";
            }

            catch (Exception ex)
            {
                _Flag = "Error in InsertLogData: " + ex.Message;
                throw ex;
            }
            finally
            {
                if (con.State == ConnectionState.Open)

                    con.Close();
                if (cmd != null)
                {
                    cmd.Dispose();
                }
                if (con != null)
                    con.Dispose();
            }
            return _Flag;
        }

        public static string DeleteSitesData(string FarmType)
        {
            SqlConnection con = null;
            SqlCommand cmd = null;
            string  _Flag = string.Empty;
            try
            {
                con = new SqlConnection(System.Configuration.ConfigurationManager.ConnectionStrings["SPOSearchConnectionString"].ToString());
                if (con.State == ConnectionState.Closed)
                    con.Open();

                cmd = new SqlCommand("usp_DeleteSitesData", con);

                cmd.CommandTimeout = 0;
                cmd.CommandType = CommandType.StoredProcedure;




                cmd.Parameters.Clear();
                cmd.Parameters.Add(new SqlParameter("@FramType", FarmType));
               


                cmd.ExecuteNonQuery();


                _Flag = "True";
            }

            catch (Exception ex)
            {
                _Flag = "Error in DeleteSitesData: " + ex.Message;
                throw ex;
            }
            finally
            {
                if (con.State == ConnectionState.Open)

                    con.Close();
                if (cmd != null)
                {
                    cmd.Dispose();
                }
                if (con != null)
                    con.Dispose();
            }
            return _Flag;
        }
    }
}