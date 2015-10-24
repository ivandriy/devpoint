/****** Object:  Table [dbo].[tblLoadSites]    Script Date: 5/16/2014 6:10:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[tblLoadSites](
	[LS_ID] [int] IDENTITY(1,1) NOT NULL,
	[LS_TITLE] [varchar](250) NULL,
	[LS_FARM] [varchar](50) NULL,
	[LS_SITE_URL] [varchar](1000) NULL,
	[LS_OWNERS] [varchar](500) NULL,
	[LS_ADMINISTRATORS] [varchar](1000) NULL,
	[LS_REMARKS] [varchar](1000) NULL,
	[LS_LAST_UPDATED] [datetime] NULL,
 CONSTRAINT [PK_tblLoadSites] PRIMARY KEY CLUSTERED 
(
	[LS_ID] ASC
)
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO
----------------------------------------------------------------------


/****** Object:  Table [dbo].[tblLogs]    Script Date: 5/16/2014 6:10:33 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[tblLogs](
	[LOG_ID] [int] IDENTITY(1,1) NOT NULL,
	[LOG_ACTION] [varchar](250) NULL,
	[LOG_DESCRIPTION] [varchar](500) NULL,
	[LOG_METHOD] [varchar](100) NULL,
	[LOG_CREATED_DATE] [datetime] NULL,
 CONSTRAINT [PK_tblLogs] PRIMARY KEY CLUSTERED 
(
	[LOG_ID] ASC
)
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO




