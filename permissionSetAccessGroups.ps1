$aRef = $accountReference | ConvertFrom-Json
$o = $operation | ConvertFrom-Json
$pRef = $permissionReference | ConvertFrom-Json
$config = $configuration | ConvertFrom-Json

$sqlInstance = $config.connection.server
$sqlDatabaseHelloId = $config.connection.database.salto_interfaces
$sqlConnectionString = "Server=$sqlInstance;Database=$sqlDatabaseHelloId;Trusted_Connection=True;Integrated Security=true;"

$success = $false
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]
$permissionType = "Access"  # DO NOT CHANGE THIS IF PERMISSIONS ARE GRANTED


$sqlDatabaseHelloIdAccountTable = $config.connection.table.salto_staging
$queryAccountToBeProcessedBySalto = "UPDATE [$sqlDatabaseHelloId].[dbo].[$sqlDatabaseHelloIdAccountTable]  SET [ToBeProcessedBySalto] = 1 WHERE ExtUserId = @accountReference;"

# Set id to the hash of the other three values to make sure a permission can only be set once
$queryCheckPermission = "SELECT [ExtZoneIDList] FROM $sqlDatabaseHelloIdAccountTable WHERE $($config.correlationAccountFieldSaltoStaging)=$aRef and  [ExtZoneIDList] like '%$($pRef.reference)%'" 
$queryGrantPermission = "UPDATE $sqlDatabaseHelloIdAccountTable SET [ToBeProcessedBySalto] = 1, [ExtZoneIDList] = '{'+TRIM(',' FROM Concat_ws(',',substring([ExtZoneIDList],2,LEN([ExtZoneIDList])-2),'$($pRef.reference)'))+'}' WHERE $($config.correlationAccountFieldSaltoStaging)=$aRef " 
$queryRevokePermission = "UPDATE $sqlDatabaseHelloIdAccountTable SET [ToBeProcessedBySalto] = 1, [ExtZoneIDList] = '{'+TRIM(',' FROM replace(','+substring([ExtZoneIDList],2,LEN([ExtZoneIDList])-2)+',','$($pRef.reference),',''))+'}' WHERE $($config.correlationAccountFieldSaltoStaging)=$aRef " 

# Make nice audit logs
$o = $o.substring(0,1).toupper()+$o.substring(1).tolower()
$oDisplay = "$($o)ed" -Replace "ee","e"

try {
    if ($o -eq "grant" -or $o -eq "revoke") {

        # Connect to the SQL server
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $sqlConnection.ConnectionString = $sqlConnectionString
        $sqlConnection.Open()

        # Setup query parameters
        $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $sqlCmd.Connection = $sqlConnection

        # Check if record already exists
        $sqlCmd.CommandText = $queryCheckPermission
        $queryMembership = $SqlCmd.ExecuteReader()
        $exists = [Bool]$queryMembership.Read()
        $queryMembership.Close()

        if (($o -eq "Grant" -and -not($exists)) -or ($o -eq "Revoke" -and $exists)) { #Only add when record doesn't exist and only delete when record exists
            $sqlCmd.CommandText = Get-Variable -Name "query$($o)Permission" -ValueOnly

            if (-not($dryRun -eq $true)) {
                $null = $SqlCmd.ExecuteNonQuery()

                # Run account query
                $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
                $sqlCmd.Connection = $sqlConnection

                $sqlCmd.CommandText = $queryAccountToBeProcessedBySalto

            } else {
                Write-Verbose -Verbose -Message "DryRun enabled, not executing query '$($sqlCmd.CommandText)'"
            }
        } else {
            Write-Verbose -Verbose -Message "No action taken on record '$($permissionMembership.id)' as action = $o and record exists = $exists"
        }

        $auditLogs.Add([PSCustomObject]@{
            Action = "$($o)Permission"
            Message = "$oDisplay access to $($permissionType) Group with external Id $($permissionMembership.permissionReference)"
            IsError = $false
        })
    }
    $success = $true
} catch {
     Write-Verbose -Verbose -Message "$($_.ScriptStackTrace)"
     $auditLogs.Add([PSCustomObject]@{
        Action = "$($o)Permission"
        Message = "$o access to $($permissionType) Group with external Id $($permissionMembership.permissionReference) failed"
        IsError = $true
    })
}

# Send results
$result = [PSCustomObject]@{
    Success = $success
    AuditLogs = $auditLogs
}

Write-Output $result | ConvertTo-Json -Depth 10