USE [SALTO_INTERFACES]
GO

/****** Object:  Table [dbo].[HelloIdUser]    Script Date: 15-10-2021 13:30:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[HelloIdUser](
	[Action] [int] NOT NULL,
	[ExtUserID] [nvarchar](32) NOT NULL,
	[FirstName] [nvarchar](40) NULL,
	[LastName] [nvarchar](40) NULL,
	[Title] [nvarchar](10) NULL,
	[Office] [bit] NOT NULL,
	[Privacy] [bit] NOT NULL,
	[AuditOpenings] [bit] NOT NULL,
	[ExtendedOpeningTimeEnabled] [bit] NOT NULL,
	[AntipassbackEnabled] [bit] NOT NULL,
	[CalendarID] [int] NULL,
	[GPF1] [nvarchar](32) NULL,
	[GPF2] [nvarchar](32) NULL,
	[GPF3] [nvarchar](32) NULL,
	[GPF4] [nvarchar](32) NULL,
	[GPF5] [nvarchar](32) NULL,
	[AutoKeyEdit.ROMCode] [nvarchar](32) NULL,
	[UserActivation] [datetime] NOT NULL,
	[UserExpiration.ExpDate] [datetime] NULL,
	[STKE.Period] [int] NULL,
	[STKE.UnitOfPeriod] [int] NULL,
	[PIN.Code] [nvarchar](8) NULL,
	[NewKeyIsCancellableThroughBL] [bit] NOT NULL,
	[ToBeProcessedBySalto] [int] NULL,
 CONSTRAINT [HelloIDCardholders_PK] PRIMARY KEY CLUSTERED 
(
	[ExtUserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIDSt__Actio__45F365D3]  DEFAULT ((3)) FOR [Action]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIDSt__Offic__46E78A0C]  DEFAULT ((0)) FOR [Office]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIDSt__Priva__47DBAE45]  DEFAULT ((0)) FOR [Privacy]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIDSt__Audit__48CFD27E]  DEFAULT ((0)) FOR [AuditOpenings]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIDSt__Exten__49C3F6B7]  DEFAULT ((0)) FOR [ExtendedOpeningTimeEnabled]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIDSt__Antip__4AB81AF0]  DEFAULT ((0)) FOR [AntipassbackEnabled]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIDSt__Calen__4BAC3F29]  DEFAULT ((0)) FOR [CalendarID]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIdUs__UserE__17036CC0]  DEFAULT (((2099)-(12))-(1)) FOR [UserExpiration.ExpDate]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIDSt__STKE.__4CA06362]  DEFAULT (NULL) FOR [STKE.Period]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIDSt__STKE.__4D94879B]  DEFAULT ((0)) FOR [STKE.UnitOfPeriod]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__HelloIDSt__NewKe__4E88ABD4]  DEFAULT ((1)) FOR [NewKeyIsCancellableThroughBL]
GO

ALTER TABLE [dbo].[HelloIdUser] ADD  CONSTRAINT [DF__Tmp_Hello__ToBeP__0A9D95DB]  DEFAULT ((1)) FOR [ToBeProcessedBySalto]
GO


