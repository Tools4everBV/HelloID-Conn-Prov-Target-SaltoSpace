function Write-HidStatus{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Message,
 
        [Parameter(Mandatory=$true)]
        [String]
        $Event
    )
    if([String]::IsNullOrEmpty($portalBaseUrl) -eq $true){
        Write-Output "[Status] $Message"
    } else {
        Hid-Write-Status -Message $Message -Event $Event
    }
}

function Write-HidSummary{
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Message,
 
        [Parameter(Mandatory=$true)]
        [String]
        $Event
    )
    if([String]::IsNullOrEmpty($portalBaseUrl) -eq $true){
        Write-Output "[Summary] $Message"
    } else {
        Hid-Write-Summary -Message $Message -Event $Event
    }
}

$type = "database" # type can be database and csv
$system = "SaltoSpace" # name of the HelloID provisioning SQL connector
$verbose = $False #Turn verbosity on or off
$sqlInstance = "SHNSALTO01\SQLEXPRESS"
$sqlDatabaseHelloId = "SALTO_INTERFACES"
$sqlDatabaseSaltoSpace = "SALTO_INTERFACES"
$saltoStagingTable = "Saltostagingtable"
$sqlDatabaseHelloIdAccountTable = "HelloIdUser"
$sqlDatabaseHelloIdMembershipTable = "HelloIdMembership"
$sqlConnectionString = "Server=$sqlInstance;Database=$sqlDatabaseHelloId;Trusted_Connection=True;Integrated Security=true;"
$sqlQueryResetToBeProcessedBySaltoUser = "UPDATE $sqlDatabaseHelloIdAccountTable SET ToBeProcessedBySalto = 0 WHERE ToBeProcessedBySalto = 1"
$sqlQueryResetToBeProcessedBySaltoMembership = "UPDATE $sqlDatabaseHelloIdMembershipTable SET ToBeProcessedBySalto = 0 WHERE ToBeProcessedBySalto = 1"

$sqlQueryMerge = "
    MERGE $saltoStagingTable AS Target
    USING (
		    SELECT
			    [Action]
		      , ExtUserID
		      , FirstName
		      , LastName
		      , Title
		      , Office
		      , Privacy
		      , AuditOpenings
		      , ExtendedOpeningTimeEnabled
		      , AntipassbackEnabled
		      , CalendarID
		      , GPF1
		      , GPF2
		      , GPF3
		      , GPF4
		      , GPF5
		      , [AutoKeyEdit.ROMCode]
		      , UserActivation
		      , [UserExpiration.ExpDate]
		      , [STKE.Period]
		      , [STKE.UnitOfPeriod]
		      , [PIN.Code]
		      , NewKeyIsCancellableThroughBL
		      , AG.permissionReferences AS ExtAccessLevelIDList
		      , LAG.permissionReference AS ExtLimitedOccupancyGroupID
		    FROM
			    $sqlDatabaseHelloIdAccountTable
			    LEFT JOIN
				    (
					    SELECT
						    accountReference
					      , STRING_AGG(permissionReference, ',') AS permissionReferences
					      , MAX(ToBeProcessedBySalto) as ToBeProcessedBySalto
					    FROM
						    $sqlDatabaseHelloIdMembershipTable
					    WHERE
						    permissionType = 'Access'
					    GROUP BY
						    accountReference
				    )
				    AS AG
				    ON
					    ExtUserID = AG.accountReference
			    LEFT JOIN
				    (
					    SELECT
						    accountReference
					      , permissionReference
					      , ToBeProcessedBySalto
					    FROM
						    $sqlDatabaseHelloIdMembershipTable
					    WHERE
						    permissionType = 'Limited Access'
				    )
				    AS LAG
				    ON
					    ExtUserID = LAG.accountReference
		    WHERE 
		        HelloIDUser.ToBeProcessedBySalto = 1 OR AG.ToBeProcessedBySalto = 1 OR  LAG.ToBeProcessedBySalto = 1
	    )
	    AS Source
    ON
	    (
		    Target.ExtUserId = Source.ExtUserId
	    )
    WHEN MATCHED THEN
    UPDATE
    SET Target.[Action]                     = Source.[Action]
      , Target.ExtUserID                    = Source.ExtUserID
      , Target.FirstName                    = Source.FirstName
      , Target.LastName                     = Source.LastName
      , Target.Title                        = Source.Title
      , Target.Office                       = Source.Office
      , Target.Privacy                      = Source.Privacy
      , Target.AuditOpenings                = Source.AuditOpenings
      , Target.ExtendedOpeningTimeEnabled   = Source.ExtendedOpeningTimeEnabled
      , Target.AntipassbackEnabled          = Source.AntipassbackEnabled
      , Target.CalendarID                   = Source.CalendarID
      , Target.GPF1                         = Source.GPF1
      , Target.GPF2                         = Source.GPF2
      , Target.GPF3                         = Source.GPF3
      , Target.GPF4                         = Source.GPF4
      , Target.GPF5                         = Source.GPF5
      , Target.[AutoKeyEdit.ROMCode]        = Source.[AutoKeyEdit.ROMCode]
      , Target.UserActivation               = Source.UserActivation
      , Target.[UserExpiration.ExpDate]     = Source.[UserExpiration.ExpDate]
      , Target.[STKE.Period]                = Source.[STKE.Period]
      , Target.[STKE.UnitOfPeriod]          = Source.[STKE.UnitOfPeriod]
      , Target.[PIN.Code]                   = Source.[PIN.Code]
      , Target.NewKeyIsCancellableThroughBL = Source.NewKeyIsCancellableThroughBL
      , Target.ExtAccessLevelIDList         = Source.ExtAccessLevelIDList
      , Target.ExtLimitedOccupancyGroupID   = Source.ExtLimitedOccupancyGroupID
      , Target.ToBeProcessedBySalto			= 1
    WHEN NOT MATCHED BY TARGET THEN
    INSERT
	    ( [Action]
	      , ExtUserID
	      , FirstName
	      , LastName
	      , Title
	      , Office
	      , Privacy
	      , AuditOpenings
	      , ExtendedOpeningTimeEnabled
	      , AntipassbackEnabled
	      , CalendarID
	      , GPF1
	      , GPF2
	      , GPF3
	      , GPF4
	      , GPF5
	      , [AutoKeyEdit.ROMCode]
	      , UserActivation
	      , [UserExpiration.ExpDate]
	      , [STKE.Period]
	      , [STKE.UnitOfPeriod]
	      , [PIN.Code]
	      , NewKeyIsCancellableThroughBL
	      , ExtAccessLevelIDList
	      , ExtLimitedOccupancyGroupID
	      , ToBeProcessedBySalto
	    )
	    VALUES
	    ( Source.[Action]
	      , Source.ExtUserID
	      , Source.FirstName
	      , Source.LastName
	      , Source.Title
	      , Source.Office
	      , Source.Privacy
	      , Source.AuditOpenings
	      , Source.ExtendedOpeningTimeEnabled
	      , Source.AntipassbackEnabled
	      , Source.CalendarID
	      , Source.GPF1
	      , Source.GPF2
	      , Source.GPF3
	      , Source.GPF4
	      , Source.GPF5
	      , Source.[AutoKeyEdit.ROMCode]
	      , Source.UserActivation
	      , Source.[UserExpiration.ExpDate]
	      , Source.[STKE.Period]
	      , Source.[STKE.UnitOfPeriod]
	      , Source.[PIN.Code]
	      , Source.NewKeyIsCancellableThroughBL
	      , Source.ExtAccessLevelIDList
	      , Source.ExtLimitedOccupancyGroupID
	      , 1 --ToBeProcessedBySalto
	    )
	  --  OUTPUT `$action
      --, Inserted.*
      --, Deleted.*
    ;
"

$sqlQueryLastUpdate = "
    SELECT
	    MAX (ius.last_user_update) AS last_user_update
    FROM
	    sys.dm_db_index_usage_stats ius
	    INNER JOIN
		    sys.tables tbl
		    ON
			    (
				    tbl.OBJECT_ID = ius.OBJECT_ID
			    )
    WHERE
	    ius.database_id = DB_ID()
	    AND
	    (
		    tbl.name    = '$sqlDatabaseHelloIdAccountTable'
		    OR tbl.name = '$sqlDatabaseHelloIdMembershipTable'
	    );"

$event = "Failed"

Write-HidStatus -Message "Starting '$type' export for provisioning connector '$system'" -Event Information

try {
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = $sqlConnectionString
    $sqlConnection.Open()
      
    $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmd.Connection = $sqlConnection
    $sqlCmd.CommandText = $sqlQueryLastUpdate
      
    $lastUpdateResult = $SqlCmd.ExecuteReader()
    while ($lastUpdateResult.Read()) {
        $lastUpdate = $lastUpdateResult.getValue(0)
    }
    $lastUpdateResult.Close()
    if ($lastUpdate -eq $null -or $lastUpdate -lt (Get-Date).AddMinutes(-1)) {   
        Write-HidStatus -Message "Writing to Salto staging table...  (Last update was at $lastUpdate)" -Event 'Information'
        $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $sqlCmd.Connection = $sqlConnection
        $sqlCmd.CommandText = $sqlQueryMerge
        $null = $SqlCmd.ExecuteNonQuery()
        $auditMessage = "exported HelloID data to $system succesfully"
        
        Write-HidStatus -Message "Resetting ToBeProcessedBySalto flag on the user table" -Event 'Information'
        $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $sqlCmd.Connection = $sqlConnection
        $sqlCmd.CommandText = $sqlQueryResetToBeProcessedBySaltoUser
        $null = $SqlCmd.ExecuteNonQuery()
        
        Write-HidStatus -Message "Resetting ToBeProcessedBySalto flag on the membership table" -Event 'Information'
        $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $sqlCmd.Connection = $sqlConnection
        $sqlCmd.CommandText = $sqlQueryResetToBeProcessedBySaltoMembership
        $null = $SqlCmd.ExecuteNonQuery()
        
        $event = "Success"
    } else {
        $auditMessage = "Database '$sqlDatabaseSaltoSpace' has been updated in the last 30 minutes ($lastUpdate), not updating now."
        $event = "success"
    }
} catch {
    $auditMessage = "Failed. Export to $system failed. Error message: $($_.Exception.Message)" 
    write-verbose -verbose $_.Exception.Message
    write-verbose -verbose ($_.InvocationInfo | convertTo-Json)
}


Write-HidStatus -Message "Finished '$type' export for provisioning connector '$system': $auditMessage" -Event $event
Write-HidSummary -Message "Finished '$type' export for provisioning connector '$system': $auditMessage" -Event $event