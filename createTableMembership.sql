USE [SALTO_INTERFACES]
GO

/****** Object:  Table [dbo].[HelloIdMembership]    Script Date: 15-10-2021 13:30:21 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[HelloIdMembership](
	[id] [nvarchar](64) NOT NULL,
	[permissionType] [nvarchar](64) NOT NULL,
	[permissionReference] [nvarchar](64) NOT NULL,
	[accountReference] [nvarchar](64) NOT NULL,
	[ToBeProcessedBySalto] [nvarchar](64) NULL,
 CONSTRAINT [PK_HelloIdMembership] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[HelloIdMembership] ADD  DEFAULT ((1)) FOR [ToBeProcessedBySalto]
GO


