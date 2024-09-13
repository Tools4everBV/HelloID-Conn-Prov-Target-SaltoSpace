##################################################
# HelloID-Conn-Prov-Target-SaltoSpace-Delete
# PowerShell V2
##################################################

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

            # Create the SqlCredential object
            $sqlCredential = [System.Data.SqlClient.SqlCredential]::new($credential.username, $credential.password)
        }

        # Connect to the SQL server
        $SqlConnection = [System.Data.SqlClient.SqlConnection]::new()
        $SqlConnection.ConnectionString = “$ConnectionString”
        if (-not[String]::IsNullOrEmpty($sqlCredential)) {
            $SqlConnection.Credential = $sqlCredential
        }
        $SqlConnection.Open()
        Write-Verbose "Successfully connected to SQL database" 

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
        Write-Verbose "Successfully disconnected from SQL database"
    }
}
#endregion

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    Write-Information 'Verifying if a SaltoSpace account exists'
    # Get account from staging table
    $account = ConvertTo-FlatObject -Object $outputContext.Data
    $sqlQueryGetAccount = "SELECT $("[" + ($account.PSObject.Properties.Name -join "],[") + "]") FROM [dbo].[$($actionContext.Configuration.dbTableStaging)] WHERE [ExtUserId] = '$($actionContext.References.Account)'"
    Write-Verbose "Running query to get account in Salto Staging table: [$sqlQueryGetAccount]"

    $sqlQueryGetAccountResult = [System.Collections.ArrayList]::new()
    $sqlQueryGetAccountSplatParams = @{
        ConnectionString = $actionContext.Configuration.connectionStringStaging
        SqlQuery         = $sqlQueryGetAccount
        ErrorAction      = 'Stop'
    }

    Invoke-SQLQuery @sqlQueryGetAccountSplatParams -Data ([ref]$sqlQueryGetAccountResult)

    $correlatedAccount = ConvertTo-FlatObject -Object $sqlQueryGetAccountResult

    if ($null -ne $correlatedAccount) {
        $action = 'DeleteAccount'
    } else {
        $action = 'NotFound'
    }

    # Process
    switch ($action) {
        'DeleteAccount' {
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Deleting SaltoSpace account with accountReference: [$($actionContext.References.Account)]"
                $sqlQueryDeleteAccount = "UPDATE [dbo].[$($actionContext.Configuration.dbTableStaging)] SET [Action] = $($actionContext.Data.Action), [ToBeProcessedBySalto] = $($actionContext.Data.ToBeProcessedBySalto) WHERE [ExtUserId] = '$($actionContext.References.Account)'"
                $sqlQueryDeleteAccountResult = [System.Collections.ArrayList]::new()
                $sqlQueryDeleteAccountSplatParams = @{
                    ConnectionString = $actionContext.Configuration.connectionStringStaging
                    SqlQuery         = $sqlQueryDeleteAccount
                    ErrorAction      = 'Stop'
                }
                Invoke-SQLQuery @sqlQueryDeleteAccountSplatParams -Data ([ref]$sqlQueryDeleteAccountResult)

            } else {
                Write-Information "[DryRun] Delete SaltoSpace account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = 'Delete account was successful'
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "SaltoSpace account: [$($actionContext.References.Account)] could not be found, possibly indicating that it could be deleted"
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "SaltoSpace account: [$($actionContext.References.Account)] could not be found, possibly indicating that it could be deleted"
                    IsError = $false
                })
            break
        }
    }
} catch {
    $outputContext.success = $false
    $ex = $PSItem

    $auditMessage = "Could not delete SaltoSpace account. Error: $($_.Exception.Message)"
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}