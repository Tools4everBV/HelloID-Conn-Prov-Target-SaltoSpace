#################################################
# HelloID-Conn-Prov-Target-SaltoSpace-Permissions-Zones-Revoke
# Revoke zone from account
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Invoke-SQLQuery {
    param(
        [parameter(Mandatory = $true)]
        $ConnectionString,

        [parameter(Mandatory = $false)]
        $Username,

        [parameter(Mandatory = $false)]
        $Password,

        [parameter(Mandatory = $true)]
        $SqlQuery,

        [parameter(Mandatory = $true)]
        [ref]$Data
    )
    try {
        $Data.value = $null

        # Initialize connection and execute query
        if (-not[String]::IsNullOrEmpty($Username) -and -not[String]::IsNullOrEmpty($Password)) {
            # First create the PSCredential object
            $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
            $credential = [System.Management.Automation.PSCredential]::new($Username, $securePassword)

            # Set the password as read only
            $credential.Password.MakeReadOnly()

            # Create the SqlCredential object
            $sqlCredential = [System.Data.SqlClient.SqlCredential]::new($credential.username, $credential.password)
        }

        # Connect to the SQL server
        $SqlConnection = [System.Data.SqlClient.SqlConnection]::new()
        $SqlConnection.ConnectionString = "$ConnectionString"
        if (-not[String]::IsNullOrEmpty($sqlCredential)) {
            $SqlConnection.Credential = $sqlCredential
        }
        $SqlConnection.Open()
        Write-Information "Successfully connected to SQL database" 

        # Set the query
        $SqlCmd = [System.Data.SqlClient.SqlCommand]::new()
        $SqlCmd.Connection = $SqlConnection
        $SqlCmd.CommandText = $SqlQuery

        # Set the data adapter
        $SqlAdapter = [System.Data.SqlClient.SqlDataAdapter]::new()
        $SqlAdapter.SelectCommand = $SqlCmd

        # Set the output with returned data
        $DataSet = [System.Data.DataSet]::new()
        $null = $SqlAdapter.Fill($DataSet)

        # Set the output with returned data
        $Data.value = $DataSet.Tables[0] | Select-Object -Property * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors
    }
    catch {
        $Data.Value = $null
        Write-Error $_
    }
    finally {
        if ($SqlConnection.State -eq "Open") {
            $SqlConnection.close()
        }
        Write-Information "Successfully disconnected from SQL database"
    }
}
#endregion

try {
    if ($actionContext.Origin -eq 'reconciliation') {
        throw  'Salto Space revoking permission is not supported with reconciliation. Skipping action.'
    }

    #region Verify account reference
    $actionMessage = "verifying account reference"
    
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw "The account reference could not be found"
    }
    #endregion Verify account reference

    #region Get Current Zones of account
    $actionMessage = "querying current zones for account with ExtID [$($actionContext.References.Account | ConvertTo-Json)]"

    $getSaltoUserCurrentZonesSplatParams = @{
        ConnectionString = $actionContext.Configuration.connectionStringStaging
        Username         = $actionContext.Configuration.username
        Password         = $actionContext.Configuration.password
        SqlQuery         = "
        SELECT
            ExtID,  
            ExtZoneIDList
        FROM
            [dbo].[$($actionContext.Configuration.dbTableStaging)]
        WHERE
            [ExtID] = '$($actionContext.References.Account)'
        "
        Verbose          = $false
        ErrorAction      = "Stop"
    }

    Write-Information "SQL Query: $($getSaltoUserCurrentZonesSplatParams.SqlQuery | Out-String)"

    $getSaltoUserCurrentZonesResponse = [System.Collections.ArrayList]::new()
    Invoke-SQLQuery @getSaltoUserCurrentZonesSplatParams -Data ([ref]$getSaltoUserCurrentZonesResponse)
    $saltoUserCurrentZones = $getSaltoUserCurrentZonesResponse.ExtZoneIDList        

    Write-Information "Queried current zones for account with ExtID [$($actionContext.References.Account | ConvertTo-Json)]. Result: $($getSaltoUserCurrentZonesResponse | ConvertTo-Json)"
    #endregion Get Current Zones of account

    if (-not [string]::IsNullOrEmpty($getSaltoUserCurrentZonesResponse.ExtID)) {
        if ($saltoUserCurrentZones -notlike "*$($actionContext.References.Permission.ExtID)*") {
            throw "User with ExtID [$($actionContext.References.Account)] is already no longer member of zone [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)]."
        }
        else {
            #region Remove account from zone
            $actionMessage = "revoking zone [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)] from account with AccountReference: $($actionContext.References.Account | ConvertTo-Json)"

            $revokePermissionSplatParams = @{
                ConnectionString = $actionContext.Configuration.connectionStringStaging
                Username         = $actionContext.Configuration.username
                Password         = $actionContext.Configuration.password
                SqlQuery         = "
            UPDATE
                [dbo].[$($actionContext.Configuration.dbTableStaging)]
            SET
                [ExtZoneIDList] = CASE
                    WHEN TRIM(',' FROM REPLACE(',' + [ExtZoneIDList] + ',', '$($actionContext.References.Permission.ExtID),', '')) = ''
                    THEN NULL
                    ELSE TRIM(',' FROM REPLACE(',' + [ExtZoneIDList] + ',', '$($actionContext.References.Permission.ExtID),', ''))
                END,
                [ToBeProcessedBySalto] = '1'
            WHERE
                [ExtID] = '$($actionContext.References.Account)'
            "
                Verbose          = $false
                ErrorAction      = "Stop"
            }
            
            Write-Information "SQL Query: $($revokePermissionSplatParams.SqlQuery | Out-String)"

            if (-Not($actionContext.DryRun -eq $true)) {
                $revokePermissionResponse = [System.Collections.ArrayList]::new()
                Invoke-SQLQuery @revokePermissionSplatParams -Data ([ref]$revokePermissionResponse)

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        # Action  = "" # Optional
                        Message = "Revoked zone [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)] from account with AccountReference: $($actionContext.References.Account | ConvertTo-Json)."
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would revoke zone [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)] from account with AccountReference: $($actionContext.References.Account | ConvertTo-Json)."
            }
            #endregion Remove account from zone
        }
    }
    else {
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                # Action  = "" # Optional
                Message = "Skipped revoking zone [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)] from account with AccountReference: $($actionContext.References.Account | ConvertTo-Json). Reason: Account not found, action skipped."
                IsError = $false
            })
    }
}
catch {
    $ex = $PSItem

    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    if ($auditMessage -like "*already no longer member*") {
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                # Action  = "" # Optional
                Message = "Skipped revoking zone [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)] from account with AccountReference: $($actionContext.References.Account | ConvertTo-Json). Reason: User is already no longer member of this zone."
                IsError = $false
            })
    }
    else {
        Write-Warning $warningMessage

        $outputContext.AuditLogs.Add([PSCustomObject]@{
                # Action = "" # Optional
                Message = $auditMessage
                IsError = $true
            })
    }
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }
}