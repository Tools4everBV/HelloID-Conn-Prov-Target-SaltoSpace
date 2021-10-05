$aRef = $accountReference | ConvertFrom-Json
$o = $operation | ConvertFrom-Json
$pRef = $permissionReference | ConvertFrom-Json
$config = $configuration | ConvertFrom-Json

$sqlInstance = $config.connection.server
$sqlDatabaseHelloId = $config.connection.database.salto_interfaces
$sqlTableMembership = $config.connection.table.helloid_membership
$sqlConnectionString = "Server=$sqlInstance;Database=$sqlDatabaseHelloId;Trusted_Connection=True;Integrated Security=true;"

$success = $false
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]
$permissionType = "Access"  # DO NOT CHANGE THIS IF PERMISSIONS ARE GRANTED

$permissionMembership = @{
    id                    = $null
    permissionType        = $permissionType
    permissionReference   = $pRef.Reference
    accountReference      = $aRef
}

# Set id to the hash of the other three values to make sure a permission can only be set once
$permissionMembership.id = -join [security.cryptography.sha256managed]::new().ComputeHash([Text.Encoding]::Utf8.GetBytes("$($permissionMembership.permissionType)_$($permissionMembership.permissionReference)_$($permissionMembership.accountReference)")).ForEach{$_.ToString("X2")}
$queryCheckPermission = "SELECT id FROM $sqlTableMembership WHERE id=@id"
$queryGrantPermission = "INSERT INTO $sqlTableMembership (id, permissionType, permissionReference, accountReference) VALUES (@id, @permissionType, @permissionReference, @accountReference);"
$queryRevokePermission = "DELETE FROM $sqlTableMembership WHERE id=@id;"

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
        $permissionMembership.Keys | Foreach-Object { $null = $sqlCmd.Parameters.Add("@" + $_, "$($permissionMembership.Item($_))") }

        # Check if record already exists
        $sqlCmd.CommandText = $queryCheckPermission
        $queryMembership = $SqlCmd.ExecuteReader()
        $exists = [Bool]$queryMembership.Read()
        $queryMembership.Close()

        if (($o -eq "Grant" -and -not($exists)) -or ($o -eq "Revoke" -and $exists)) { #Only add when record doesn't exist and only delete when record exists
            $sqlCmd.CommandText = Get-Variable -Name "query$($o)Permission" -ValueOnly
            if (-not($dryRun -eq $true)) {
                $null = $SqlCmd.ExecuteNonQuery()
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