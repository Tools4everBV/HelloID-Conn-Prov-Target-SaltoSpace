#################################################
# HelloID-Conn-Prov-Target-SaltoSpace-Permissions-Groups-Grant
# Grant group to account
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
    #region Verify account reference
    $actionMessage = "verifying account reference"
    
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw "The account reference could not be found"
    }
    #endregion Verify account reference

    #region Get Current Groups of account
    $actionMessage = "querying current groups for account with ExtID [$($actionContext.References.Account | ConvertTo-Json)]"

    $getSaltoUserCurrentGroupsSplatParams = @{
        ConnectionString = $actionContext.Configuration.connectionStringStaging
        Username         = $actionContext.Configuration.username
        Password         = $actionContext.Configuration.password
        SqlQuery         = "
        SELECT
            ExtID,  
            ExtAccessLevelIDList
        FROM
            [dbo].[$($actionContext.Configuration.dbTableStaging)]
        WHERE
            [ExtID] = '$($actionContext.References.Account)'
        "
        Verbose          = $false
        ErrorAction      = "Stop"
    }

    Write-Information "SQL Query: $($getSaltoUserCurrentGroupsSplatParams.SqlQuery | Out-String)"

    $getSaltoUserCurrentGroupsResponse = [System.Collections.ArrayList]::new()
    Invoke-SQLQuery @getSaltoUserCurrentGroupsSplatParams -Data ([ref]$getSaltoUserCurrentGroupsResponse)
    $saltoUserCurrentGroups = $getSaltoUserCurrentGroupsResponse.ExtAccessLevelIDList

    Write-Information "Queried current groups for account with ExtID [$($actionContext.References.Account | ConvertTo-Json)]. Result: $($getSaltoUserCurrentGroupsResponse | ConvertTo-Json)"
    #endregion Get Current Groups of account

    if (-not [string]::IsNullOrEmpty($getSaltoUserCurrentGroupsResponse.ExtID)) {
        if ($saltoUserCurrentGroups -like "*$($actionContext.References.Permission.ExtID)*") {
            throw "User with ExtID [$($actionContext.References.Account)] is already member of group [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)]."
        }
        else {
            #region Add account to group
            $actionMessage = "granting group [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)] to account with AccountReference: $($actionContext.References.Account | ConvertTo-Json)"

            $grantPermissionSplatParams = @{
                ConnectionString = $actionContext.Configuration.connectionStringStaging
                Username         = $actionContext.Configuration.username
                Password         = $actionContext.Configuration.password
                SqlQuery         = "
            UPDATE
                [dbo].[$($actionContext.Configuration.dbTableStaging)]
            SET
                [ExtAccessLevelIDList] = TRIM(',' FROM Concat_ws(',', [ExtAccessLevelIDList], '$($actionContext.References.Permission.ExtID)')),
                [ToBeProcessedBySalto] = '1'
            WHERE
                [ExtID] = '$($actionContext.References.Account)'
            "
                Verbose          = $false
                ErrorAction      = "Stop"
            }
            
            Write-Information "SQL Query: $($grantPermissionSplatParams.SqlQuery | Out-String)"
        
            if (-Not($actionContext.DryRun -eq $true)) {
                $grantPermissionResponse = [System.Collections.ArrayList]::new()
                Invoke-SQLQuery @grantPermissionSplatParams -Data ([ref]$grantPermissionResponse)
            
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        # Action  = "" # Optional
                        Message = "Granted group [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)] to account with AccountReference: $($actionContext.References.Account | ConvertTo-Json)."
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would grant group [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)] to account with AccountReference: $($actionContext.References.Account | ConvertTo-Json)."
            }
            #endregion Add account to group
        }
    }
    else {
        throw "No account found where [ExtID] = [$($actionContext.References.Account)]."
    }
}
catch {
    $ex = $PSItem

    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    if ($auditMessage -like "*already member of group*") {
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                # Action  = "" # Optional
                Message = "Skipped granting group [$($actionContext.PermissionDisplayName)] with ExtID [$($actionContext.References.Permission.ExtID)] to account with AccountReference: $($actionContext.References.Account | ConvertTo-Json). Reason: User is already member of this group."
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