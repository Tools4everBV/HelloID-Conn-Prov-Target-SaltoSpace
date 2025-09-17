#################################################
# HelloID-Conn-Prov-Target-SaltoSpace-Update
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
    $correlationField = "ExtID"
    $correlationValue = $actionContext.References.Account

    # Define account object
    $account = $actionContext.Data.PsObject.Copy()
    $account = ConvertTo-FlatObject -Object $account

    $accountPropertiesToCompare = $account.PsObject.Properties.Name | Select-Object -ExcludeProperty 'ToBeProcessedBySalto'
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

    $correlatedAccount = $getSaltoStagingAccountResponse
    if (($correlatedAccount | Measure-Object).count -gt 0) {
        $correlatedAccount = ConvertTo-FlatObject -Object $correlatedAccount
    }

    Write-Information "Queried account where [$correlationField] = [$correlationValue] from Salto Staging DB. Result: $($correlatedAccount | ConvertTo-Json)"
    #endregion Get account from Salto Staging DB

    #region Calulate action
    $actionMessage = "calculating action"
    if (($correlatedAccount | Measure-Object).count -eq 1) {
        $actionMessage = "comparing current account to mapped properties"

        # Change NULL to Empty to make a correct compare
        $correlatedAccount.PSObject.Properties | ForEach-Object { if ($null -eq $_.Value -or $_.Value -eq 'NULL') { $_.Value = "" } }
        $account.PSObject.Properties | ForEach-Object { if ($null -eq $_.Value -or $_.Value -eq 'NULL') { $_.Value = "" } }

        # Set Previous data (if there are no changes between PreviousData and Data, HelloID will log "update finished with no changes")
        $outputContext.PreviousData = $correlatedAccount

        $accountSplatCompareProperties = @{
            ReferenceObject  = $correlatedAccount.PSObject.Properties | Where-Object { $_.Name -in $accountPropertiesToCompare }
            DifferenceObject = $account.PSObject.Properties | Where-Object { $_.Name -in $accountPropertiesToCompare }
        }

        if ($null -ne $accountSplatCompareProperties.ReferenceObject -and $null -ne $accountSplatCompareProperties.DifferenceObject) {
            $accountPropertiesChanged = Compare-Object @accountSplatCompareProperties -PassThru
            $accountNewProperties = $accountPropertiesChanged | Where-Object { $_.SideIndicator -eq "=>" }
        }

        if ($accountNewProperties) {
            Write-Information "Changed properties: [$($accountNewProperties.name -join ',')]"
            $actionAccount = "Update"
        }
        else {
            $actionAccount = "NoChanges"
        }

        Write-Information "Compared current account to mapped properties. Result: $actionAccount"
    }
    elseif (($correlatedAccount | Measure-Object).count -eq 0) {
        # NotFound replaced by Create because import account entitlements can be used
        $actionAccount = "Create"
    }
    elseif (($correlatedAccount | Measure-Object).count -gt 1) {
        $actionAccount = "MultipleFound"
    }
    #endregion Calulate action

    #region Process
    switch ($actionAccount) {
        "Create" {
            #region Create account
            $actionMessage = "querying account where [$($correlationField)] = [$($correlationValue)] from Salto DB"

            $getSaltoAccountSplatParams = @{
                ConnectionString = $actionContext.Configuration.connectionStringSalto
                Username         = $actionContext.Configuration.username
                Password         = $actionContext.Configuration.password
                SqlQuery         = "
                SELECT
                    tb_Users.dtActivation
                FROM
                    [dbo].[tb_Users]
                    INNER JOIN [dbo].[tb_Users_Ext] ON tb_Users.id_user = tb_Users_Ext.id_user
                WHERE
                    [$correlationField] = '$correlationValue'
                "
                Verbose          = $false
                ErrorAction      = "Stop"
            }

            Write-Information "SQL Query: $($getSaltoAccountSplatParams.SqlQuery | Out-String)"

            $getSaltoAccountResponse = [System.Collections.ArrayList]::new()
            Invoke-SQLQuery @getSaltoAccountSplatParams -Data ([ref]$getSaltoAccountResponse)

            Write-Information "Queried account where [$($correlationField)] = [$($correlationValue)] from Salto DB. Result: $($getSaltoAccountResponse | ConvertTo-Json)"

            # Make sure to use the same Activation date that is used in Salto
            if (($getSaltoAccountResponse | Measure-Object).count -gt 0) {
                $getSaltoAccountResponse = ConvertTo-FlatObject -Object $getSaltoAccountResponse
                $account | Add-Member -NotePropertyName 'dtActivation' -NotePropertyValue $getSaltoAccountResponse.dtActivation -Force
            }
            else {
                $account | Add-Member -NotePropertyName 'dtActivation' -NotePropertyValue '12/01/2099 00:00:00' -Force
            }

            $actionMessage = "creating account with FirstName [$($account.FirstName)] and LastName [$($account.LastName)]"

            # Set ExtID with ExtID of user in Salto DB
            $account | Add-Member -NotePropertyName 'ExtID' -NotePropertyValue $actionContext.References.Account -Force

            $createAccountSplatParams = @{
                ConnectionString = $actionContext.Configuration.connectionStringStaging
                Username         = $actionContext.Configuration.username
                Password         = $actionContext.Configuration.password
                SqlQuery         = "
                INSERT INTO
                    [dbo].[$($actionContext.Configuration.dbTableStaging)] ([$($account.PSObject.Properties.Name -join "],[")],[ToBeProcessedBySalto])
                VALUES
                    ($($account.PSObject.Properties.Value.ForEach({ if (($_ -eq $null -or $_ -eq 'NULL')) { 'NULL' } else { '''' + $_.Replace("'", "''") + '''' } }) -join ', '),'1')
                "
                Verbose          = $false
                ErrorAction      = "Stop"
            }

            Write-Information "SQL Query: $($createAccountSplatParams.SqlQuery | Out-String)"

            if (-Not($actionContext.DryRun -eq $true)) {
                $createAccountResponse = [System.Collections.ArrayList]::new()
                Invoke-SQLQuery @createAccountSplatParams -Data ([ref]$createAccountResponse)

                $outputContext.PreviousData = $null

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        # Action  = "" # Optional
                        Message = "Created staging DB record with FirstName [$($account.FirstName)] and LastName [$($account.LastName)] with AccountReference: $($outputContext.AccountReference | ConvertTo-Json)."
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would staging DB record with FirstName [$($account.FirstName)], LastName [$($account.LastName)] and ExtID [$($account.ExtID)]."
            }
            #endregion Create account

            break
        }
        
        "Update" {
            #region Update account
            $actionMessage = "updating account with AccountReference: $($actionContext.References.Account | ConvertTo-Json)"

            # Create a list of properties to update
            $updatePropertiesList = [System.Collections.Generic.List[string]]::new()

            foreach ($accountNewProperty in $accountNewProperties) {
                # Define the value, handling nulls and escaping single quotes
                $value = if (([String]::IsNullOrEmpty($accountNewProperty.Value)) -or $accountNewProperty.Value -eq 'NULL') {
                    'NULL'
                }
                else {
                    "'$($accountNewProperty.Value -replace "'", "''")'"
                }

                # Add the property to the list
                $updatePropertiesList.Add("[$($accountNewProperty.Name)] = $value")
            }

            $updateAccountSplatParams = @{
                ConnectionString = $actionContext.Configuration.connectionStringStaging
                Username         = $actionContext.Configuration.username
                Password         = $actionContext.Configuration.password
                SqlQuery         = "
                UPDATE
                    [dbo].[$($actionContext.Configuration.dbTableStaging)]
                SET
                    $(if(-NOT [string]::IsNullOrEmpty($updatePropertiesList)){($updatePropertiesList -join ',') + ','})
                    [ToBeProcessedBySalto] = '1'
                WHERE
                    [ExtID] = '$($actionContext.References.Account)'
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
                        Message = "Updated account with AccountReference: $($outputContext.AccountReference | ConvertTo-Json), Account property(s) updated: [$($accountNewProperties.name -join ',')]"
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would update account with AccountReference: $($outputContext.AccountReference | ConvertTo-Json), Account property(s) updated: [$($accountNewProperties.name -join ',')]"
            }
            #endregion Update account

            break
        }

        "NoChanges" {
            #region No changes
            $actionMessage = "skipping updating account"

            $outputContext.Data = $correlatedAccount

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    # Action  = "" # Optional
                    Message = "Skipped updating account with AccountReference: $($actionContext.References.Account | ConvertTo-Json). Reason: No changes."
                    IsError = $false
                })
            #endregion No changes

            break
        }

        "MultipleFound" {
            #region Multiple accounts found
            $actionMessage = "updating account"

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