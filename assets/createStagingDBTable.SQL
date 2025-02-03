USE [Salto_STAGING]
GO
    /****** Object:  Table [dbo].[SaltoCardholdersSQLServer]    Script Date: 11/1/2024 4:31:38 PM ******/
SET
    ANSI_NULLS ON
GO
SET
    QUOTED_IDENTIFIER ON
GO
    CREATE TABLE [dbo].[SaltoCardholdersSQLServer](
        [ToBeProcessedBySalto] [int] NOT NULL,
        [ProcessedDateTime] [datetime] NOT NULL,
        [ErrorCode] [int] NOT NULL,
        [ErrorMessage] [nvarchar](512) NULL,
        [Action] [int] NOT NULL,
        [ExtID] [nvarchar](32) NOT NULL,
        [dtActivation] [datetime] NOT NULL,
        [dtExpiration] [datetime] NULL,
        [FirstName] [nvarchar](40) NULL,
        [LastName] [nvarchar](50) NULL,
        [Dummy1] [nvarchar](40) NULL,
        [Dummy2] [nvarchar](40) NULL,
        [Dummy3] [nvarchar](40) NULL,
        [Dummy4] [nvarchar](40) NULL,
        [Dummy5] [nvarchar](40) NULL,
        [PhoneNumber] [varchar](50) NULL,
        [ExtZoneIDList] [nvarchar](1024) NULL,
        [ExtDoorIDList] [nvarchar](1024) NULL,
        [ExtAccessLevelIDList] [nvarchar](1024) NULL,
        [Title] [nvarchar](10) NULL,
        [office] [bit] NOT NULL,
        [Privacy] [bit] NOT NULL,
        [AuditOpenings] [bit] NOT NULL,
        [ExtendedOpeningTime] [bit] NOT NULL,
        [AntipassbackEnabled] [bit] NOT NULL,
        [MobileAppType] [int] NOT NULL,
        [UseLockCalendar] [bit] NOT NULL,
        [CalendarID] [int] NULL,
        [AutoKeyEdit.ROMCode] [varchar](32) NULL,
        [STKE.Period] [int] NULL,
        [STKE.UnitOfPeriod] [int] NULL,
        [PIN.Code] [varchar](8) NULL,
        [WiegandCode] [varchar](32) NULL,
        [NewKeyIsCancellableThroughBL] [bit] NOT NULL,
        [PictureFileName] [varchar](255) NULL,
        [AuthorizationCodeList] [nvarchar](1024) NULL,
        [ExtLimitedOccupancyGroupID] [varchar](40) NULL,
        CONSTRAINT [SaltoCardholders_PK] PRIMARY KEY CLUSTERED ([ExtID] ASC) WITH (
            PAD_INDEX = OFF,
            STATISTICS_NORECOMPUTE = OFF,
            IGNORE_DUP_KEY = OFF,
            ALLOW_ROW_LOCKS = ON,
            ALLOW_PAGE_LOCKS = ON,
            OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
        ) ON [PRIMARY]
    ) ON [PRIMARY]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((1)) FOR [ToBeProcessedBySalto]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT (getdate()) FOR [ProcessedDateTime]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((0)) FOR [ErrorCode]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((3)) FOR [Action]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((0)) FOR [office]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((0)) FOR [Privacy]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((0)) FOR [AuditOpenings]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((0)) FOR [ExtendedOpeningTime]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((0)) FOR [AntipassbackEnabled]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((0)) FOR [MobileAppType]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((0)) FOR [UseLockCalendar]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((0)) FOR [CalendarID]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((30)) FOR [STKE.Period]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((0)) FOR [STKE.UnitOfPeriod]
GO
ALTER TABLE
    [dbo].[SaltoCardholdersSQLServer]
ADD
    DEFAULT ((1)) FOR [NewKeyIsCancellableThroughBL]
GO