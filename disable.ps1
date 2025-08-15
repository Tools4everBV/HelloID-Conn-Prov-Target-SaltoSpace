#################################################
# HelloID-Conn-Prov-Target-SaltoSpace-Disable
# PowerShell V2
# TODO testing new active process this: (on disable)
# dtActivation: Don't update
# dtExpiration: Yesterday
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
        $SqlConnection.ConnectionString = “$ConnectionString”
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

function ConvertTo-FlatObject {
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Object,
        [string] $Prefix = ""
    )
    $result = [ordered]@{}

    foreach ($property in $Object.PSObject.Properties) {
        $name = if ($Prefix) { "$Prefix`.$($property.Name)" } else { $property.Name }

        if ($property.Value -is [pscustomobject]) {
            $flattenedSubObject = ConvertTo-FlatObject -Object $property.Value -Prefix $name
            foreach ($subProperty in $flattenedSubObject.PSObject.Properties) {
                # Convert boolean values of true and false to string values of 1 and 0
                if ($subProperty.Value -eq $true) {
                    $result[$subProperty.Name] = '1'
                }
                elseif ($subProperty.Value -eq $false) {
                    $result[$subProperty.Name] = '0'
                }
                elseif ($null -eq $subProperty.Value -or $subProperty.Value -is [System.DBNull]) {
                    $result[$subProperty.Name] = $null
                }
                else {
                    $result[$subProperty.Name] = [string]$subProperty.Value
                }
            }
        }
        else {
            # Convert boolean values of true and false to string values of 1 and 0
            if ($property.Value -eq $true) {
                $result[$name] = '1'
            }
            elseif ($property.Value -eq $false) {
                $result[$name] = '0'
            }
            elseif ($null -eq $property.Value -or $property.Value -is [System.DBNull]) {
                $result[$name] = $null
            }
            else {
                $result[$name] = [string]$property.Value
            }
        }
    }
    Write-Output ([PSCustomObject]$result)
}
#endregion

try {
    #region account
    # Define correlation
    $correlationField = "ExtId"
    $correlationValue = $actionContext.References.Account

    # Define account object
    if ($actionContext.Origin -eq 'reconciliation') {
        throw  'Salto Space disabling account is not supported with reconciliation. Skipping action.'
    }

    $account = [PSCustomObject]$actionContext.Data.PsObject.Copy()
    $account = ConvertTo-FlatObject -Object $account
    #endRegion account

    #region Verify account reference
    $actionMessage = "verifying account reference"
    
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw "The account reference could not be found"
    }
    #endregion Verify account reference

    #region Get account from Salto Staging DB
    $actionMessage = "querying account where [$correlationField] = [$correlationValue] from Salto Staging DB"

    $getSaltoStagingAccountSplatParams = @{
        ConnectionString = $actionContext.Configuration.connectionStringStaging
        Username         = $actionContext.Configuration.username
        Password         = $actionContext.Configuration.password
        SqlQuery         = "
        SELECT
            [$($account.PSObject.Properties.Name -join "],[")]
        FROM
            [dbo].[$($actionContext.Configuration.dbTableStaging)]
        WHERE
            [$correlationField] = '$correlationValue'
        "
        Verbose          = $false
        ErrorAction      = "Stop"
    }

    Write-Information "SQL Query: $($getSaltoStagingAccountSplatParams.SqlQuery | Out-String)"

    $getSaltoStagingAccountResponse = [System.Collections.ArrayList]::new()
    Invoke-SQLQuery @getSaltoStagingAccountSplatParams -Data ([ref]$getSaltoStagingAccountResponse)

    Write-Information "Queried account where [$correlationField] = [$correlationValue] from Salto Staging DB. Result: $($correlatedAccount | ConvertTo-Json)"
    #endregion Get account from Salto Staging DB

    $correlatedAccount = $getSaltoStagingAccountResponse
    if (($correlatedAccount | Measure-Object).count -gt 0) {
        $correlatedAccount = ConvertTo-FlatObject -Object $correlatedAccount
    }
    
    #region Calculated action
    $actionMessage = "calculating action"
    if (($correlatedAccount | Measure-Object).count -eq 1) {
        $actionAccount = "Disable"
    }
    elseif (($correlatedAccount | Measure-Object).count -eq 0) {
        $actionAccount = "NotFound"
    }
    elseif (($correlatedAccount | Measure-Object).count -gt 1) {
        $actionAccount = "MultipleFound"
    }
    Write-Information "Calculated action: $actionAccount"
    #endregion Calculated action

    #region Process
    switch ($actionAccount) {
        "Disable" {
            #region Update account             
            $actionMessage = "disabling account with AccountReference: $($actionContext.References.Account | ConvertTo-Json)"
           
            $accountNewProperties = $actionContext.Data.PSObject.Properties # Quick fix om het werkend te maken, mogelijk compare toevoegen?

            # Create a list of properties to update
            $updatePropertiesList = [System.Collections.Generic.List[string]]::new()

            foreach ($accountNewProperty in $accountNewProperties) {
                # Define the value, handling nulls and escaping single quotes
                #$value = if ($accountNewProperty.Value -eq $null) {
                $value = if ([String]::IsNullOrEmpty($accountNewProperty.Value)) {
                    'NULL'
                }
                else {
                    "'$($accountNewProperty.Value -replace "'", "''")'"
                }
                
                # Add the property to the list
                $updatePropertiesList.Add("[$($accountNewProperty.Name)] = $value")
            }
            
            # $updateAccountSplatParams = @{
            #     ConnectionString = $actionContext.Configuration.connectionStringStaging
            #     Username         = $actionContext.Configuration.username
            #     Password         = $actionContext.Configuration.password
            #     SqlQuery         = "
            #     UPDATE
            #         [dbo].[$($actionContext.Configuration.dbTableStaging)]
            #     SET
            #         $($updatePropertiesList -join ','),
            #         [Action] = '$($actionContext.data.Action)',
            #         [ToBeProcessedBySalto] = '1'
            #     WHERE
            #         [ExtId] = '$($actionContext.References.Account)'
            #     "
            #     Verbose          = $false
            #     ErrorAction      = "Stop"
            # }

            $updateAccountSplatParams = @{
                ConnectionString = $actionContext.Configuration.connectionStringStaging
                Username         = $actionContext.Configuration.username
                Password         = $actionContext.Configuration.password
                SqlQuery         = "
                UPDATE
                    [dbo].[$($actionContext.Configuration.dbTableStaging)]
                SET
                    $($updatePropertiesList -join ','),
                    [ToBeProcessedBySalto] = '1'
                WHERE
                    [ExtId] = '$($actionContext.References.Account)'
                "
                Verbose          = $false
                ErrorAction      = "Stop"
            }       
        
            Write-Information "SQL Query: $($updateAccountSplatParams.SqlQuery | Out-String)"

            if (-Not($actionContext.DryRun -eq $true)) {
                $updateAccountResponse = [System.Collections.ArrayList]::new()
                Invoke-SQLQuery @updateAccountSplatParams -Data ([ref]$updateAccountResponse)

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        # Action  = "" # Optional
                        Message = "Disabled account with AccountReference: $($outputContext.AccountReference | ConvertTo-Json)."
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would disable account with AccountReference: $($outputContext.AccountReference | ConvertTo-Json)."
            }
            #endregion Update account

            break
        }

        "NotFound" {
            #region No account found
            $actionMessage = "skipping disabling account"

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    # Action  = "" # Optional
                    Message = "Could not disable account with AccountReference: $($outputContext.AccountReference | ConvertTo-Json). Account not found, action skipped."
                    IsError = $false
                })
            #endregion No account found

            break
        }

        "MultipleFound" {
            #region Multiple accounts found
            $actionMessage = "disabling account"

            # Throw terminal error
            throw "Multiple accounts found where [$($correlationField)] = [$($correlationValue)]. Please correct this to ensure the correlation results in a single unique account."
            #endregion Multiple accounts found

            break
        }
    }
    #endregion Process
}
catch {
    $ex = $PSItem

    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    Write-Warning $warningMessage

    $outputContext.AuditLogs.Add([PSCustomObject]@{
            # Action = "" # Optional
            Message = $auditMessage
            IsError = $true
        })
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }
}