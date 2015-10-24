
/****** Object:  StoredProcedure [dbo].[usp_InsertSitesData]    Script Date: 5/16/2014 6:11:37 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_InsertSitesData]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_InsertSitesData]
GO



/****** Object:  StoredProcedure [dbo].[usp_InsertSitesData]    Script Date: 7/30/2014 9:47:53 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[usp_InsertSitesData] 
	-- Add the parameters for the stored procedure here
	@LS_TITLE varchar(250),
	@LS_FARM varchar(50),
    @LS_SITE_URL varchar(1000),
    @LS_OWNERS varchar(500),
    @LS_ADMINISTRATORS varchar(1000),
    @LS_REMARKS varchar(1000)
AS
BEGIN
	
	INSERT INTO tblLoadSites
           ([LS_TITLE]
           ,[LS_FARM]
           ,[LS_SITE_URL]
           ,[LS_OWNERS]
           ,[LS_ADMINISTRATORS]
           ,[LS_REMARKS]
           ,[LS_LAST_UPDATED]
		   ,CreatedBy
		   ,CreatedDate
		   ,ModifiedBy
		   ,ModifiedDate
		   )
     VALUES
		(
		@LS_TITLE,
		@LS_FARM,
		@LS_SITE_URL,
		@LS_OWNERS,
		@LS_ADMINISTRATORS,
		@LS_REMARKS,
		getdate(),
		'Administrator',
		getdate(),
		'Administrator',
		getdate()

		)

	
 
END


GO






-----------------------------------------------------------------------

/****** Object:  StoredProcedure [dbo].[usp_InsertLogsData]    Script Date: 5/16/2014 6:11:50 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_InsertLogsData]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_InsertLogsData]
GO

/****** Object:  StoredProcedure [dbo].[usp_InsertLogsData]    Script Date: 5/26/2014 12:15:51 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[usp_InsertLogsData] 
	-- Add the parameters for the stored procedure here
	@LOG_ACTION varchar(250),
	@LOG_DESCRIPTION varchar(500),
	@LOG_METHOD varchar(100)
AS
BEGIN
	
	INSERT INTO tblLogs
           (
		[LOG_ACTION] ,
		[LOG_DESCRIPTION] ,
		[LOG_CREATED_DATE] ,
		LOG_METHOD		   )
     VALUES
		(
		@LOG_ACTION,
		@LOG_DESCRIPTION,
	
		getdate(),
		@LOG_METHOD
		)

	
 
END




GO



------------------------------------------------------------

/****** Object:  StoredProcedure [dbo].[usp_DeleteSitesData]    Script Date: 5/16/2014 6:14:20 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_DeleteSitesData]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_DeleteSitesData]
GO

/****** Object:  StoredProcedure [dbo].[usp_DeleteSitesData]    Script Date: 5/26/2014 12:16:23 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[usp_DeleteSitesData] 
	-- Add the parameters for the stored procedure here
	@FramType varchar(50)
AS
BEGIN
	
	if exists (Select 'X' From tblLoadSites
	Where LS_FARM='SPO')
	Begin
	Delete  From tblLoadSites
	Where LS_FARM='SPO' 
	End
 
END


GO
--------------------------------------------------------------------

/****** Object:  StoredProcedure [dbo].[usp_InsertEventLogsData]    Script Date: 5/16/2014 6:14:20 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_InsertEventLogsData]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_InsertEventLogsData]
GO

/****** Object:  StoredProcedure [dbo].[usp_InsertEventLogsData]    Script Date: 7/30/2014 9:51:08 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[usp_InsertEventLogsData] 
	-- Add the parameters for the stored procedure here
	@EVENT_LOG_NAME varchar(150),
	@EVENT_LOG_VALUE varchar(500)
AS
BEGIN
	
	INSERT INTO tblEventLogMaster
           (
		EVENT_LOG_NAME ,
		EVENT_LOG_VALUE ,
		EVENT_LOG_DATE ,
		 CreatedBy
		   ,CreatedDate
		   ,ModifiedBy
		   ,ModifiedDate
				   )
     VALUES
		(
		@EVENT_LOG_NAME,
		@EVENT_LOG_VALUE,
		getdate(),
		'Administrator',
		getdate(),
		'Administrator',
		getdate()
		)

	
 
END
GO
-----------------------------------------------------------------------------

/****** Object:  StoredProcedure [dbo].[usp_SearchSitesData]    Script Date: 5/16/2014 6:14:20 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_SearchSitesData]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_SearchSitesData]
GO

/****** Object:  StoredProcedure [dbo].[usp_SearchSitesData]    Script Date: 8/26/2014 2:52:30 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[usp_SearchSitesData]
(
@Searchvalue varchar(500)
)
As
Begin
Declare 
@StrQuery varchar(2000)

if isnull(@Searchvalue,'') = ''
Begin
	SELECT [LS_ID]
		  ,[LS_TITLE]
		  ,[LS_FARM]
		  ,[LS_SITE_URL]
		  ,[LS_OWNERS]
		  ,[LS_ADMINISTRATORS]
		  ,[LS_REMARKS] 
	From tblLoadSites

End
Else
Begin
	Set @Searchvalue = '%'+@Searchvalue+'%'
	

	SELECT [LS_ID]
		  ,[LS_TITLE]
		  ,[LS_FARM]
		  ,[LS_SITE_URL]
		  ,[LS_OWNERS]
		  ,[LS_ADMINISTRATORS]
		  ,[LS_REMARKS]
	From tblLoadSites
	Where LS_TITLE like @Searchvalue 
	Or LS_FARM like @Searchvalue 
	Or LS_SITE_URL like @Searchvalue 
	Or LS_OWNERS like @Searchvalue
	Or LS_ADMINISTRATORS like @Searchvalue
	Or LS_REMARKS like @Searchvalue
End



End

GO
















