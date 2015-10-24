using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data.SqlClient;
using System.Data;
namespace UMSPO.Models
{
    public class EventMasterData
    {
        public string EventLogName { get; set; }
        public string EventLogValue{ get; set; }
    }
    public class clsEventLogMasterDB
    {

        public static string InsertEventLogMasterData(EventMasterData objEventLogData)
        {
            SqlConnection con = null;
            SqlCommand cmd = null;
            string _Flag = string.Empty;
            try
            {
                con = new SqlConnection(System.Configuration.ConfigurationManager.ConnectionStrings["SPOSearchConnectionString"].ToString());
                if (con.State == ConnectionState.Closed)
                    con.Open();

                cmd = new SqlCommand("usp_InsertEventLogsData", con);

                cmd.CommandTimeout = 0;
                cmd.CommandType = CommandType.StoredProcedure;




                cmd.Parameters.Clear();
                cmd.Parameters.Add(new SqlParameter("@EVENT_LOG_NAME", objEventLogData.EventLogName));
                cmd.Parameters.Add(new SqlParameter("@EVENT_LOG_VALUE", objEventLogData.EventLogValue));

                cmd.ExecuteNonQuery();


                _Flag = "True";
            }

            catch (Exception ex)
            {
                _Flag = "Error in InsertEventLogMasterData: " + ex.Message;
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