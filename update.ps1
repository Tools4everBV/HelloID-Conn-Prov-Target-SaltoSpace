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
    $account = [PSCustomObject]$actionContext.Data.PsObject.Copy()
    $account = ConvertTo-FlatObject -Object $account

    # Define properties to compare for update
    $accountPropertiesToCompare = $account.PsObject.Properties.Name | Select-Object -ExcludeProperty 'Action', 'ToBeProcessedBySalto'
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
    
    #region Calulate action
    $actionMessage = "calculating action"
    if (($correlatedAccount | Measure-Object).count -eq 1) {
        $actionMessage = "comparing current account to mapped properties"

        # Set Previous data (if there are no changes between PreviousData and Data, HelloID will log "update finished with no changes")
        $outputContext.PreviousData = $correlatedAccount.PsObject.Copy()

        # Create reference object from correlated account
        $accountReferenceObject = $correlatedAccount.PsObject.Copy()

        # Create difference object from mapped properties
        $accountDifferenceObject = $account.PsObject.Copy()

        $accountSplatCompareProperties = @{
            ReferenceObject  = $accountReferenceObject.PSObject.Properties | Where-Object { $_.Name -in $accountPropertiesToCompare }
            DifferenceObject = $accountDifferenceObject.PSObject.Properties | Where-Object { $_.Name -in $accountPropertiesToCompare }
        }

        if ($null -ne $accountSplatCompareProperties.ReferenceObject -and $null -ne $accountSplatCompareProperties.DifferenceObject) {
            $accountPropertiesChanged = Compare-Object @accountSplatCompareProperties -PassThru
            $accountOldProperties = $accountPropertiesChanged | Where-Object { $_.SideIndicator -eq "<=" }
            $accountNewProperties = $accountPropertiesChanged | Where-Object { $_.SideIndicator -eq "=>" }
        }

        if ($accountNewProperties) {
            # Create custom object with old and new values
            $accountChangedPropertiesObject = [PSCustomObject]@{
                OldValues = @{}
                NewValues = @{}
            }

            # Add the old properties to the custom object with old and new values
            foreach ($accountOldProperty in $accountOldProperties) {
                $accountChangedPropertiesObject.OldValues.$($accountOldProperty.Name) = $accountOldProperty.Value
            }

            # Add the new properties to the custom object with old and new values
            foreach ($accountNewProperty in $accountNewProperties) {
                $accountChangedPropertiesObject.NewValues.$($accountNewProperty.Name) = $accountNewProperty.Value
            }

            Write-Information "Changed properties: $($accountChangedPropertiesObject | ConvertTo-Json)"

            $actionAccount = "Update"
        }
        else {
            $actionAccount = "NoChanges"
        }            

        Write-Information "Compared current account to mapped properties. Result: $actionAccount"
    }
    elseif (($correlatedAccount | Measure-Object).count -eq 0) {
        $actionAccount = "NotFound"
        if ($actionContext.AccountCorrelated -eq $true) {
            Write-Information 'Inserting record in staging database after import account'
            $actionAccount = "Create"
        }
    }
    elseif (($correlatedAccount | Measure-Object).count -gt 1) {
        $actionAccount = "MultipleFound"
    }
    #endregion Calulate action

    #region Process
    switch ($actionAccount) {
        "Create" {
            #region Create account                  
            $actionMessage = "creating account with FirstName [$($account.FirstName)] and LastName [$($account.LastName)]"

            # Set ExtId with ExtID of user in Salto DB
            $account | Add-Member -NotePropertyName 'ExtId' -NotePropertyValue $actionContext.References.Account -Force
            
            $createAccountSplatParams = @{
                ConnectionString = $actionContext.Configuration.connectionStringStaging
                Username         = $actionContext.Configuration.username
                Password         = $actionContext.Configuration.password
                SqlQuery         = "
                INSERT INTO
                    [dbo].[$($actionContext.Configuration.dbTableStaging)] ([$($account.PSObject.Properties.Name -join "],[")],[ToBeProcessedBySalto])
                VALUES
                    ($($account.PSObject.Properties.Value.ForEach({ if ($_ -eq $null) { 'NULL' } else { '''' + $_.Replace("'", "''") + '''' } }) -join ', '),'1')
                "
                Verbose          = $false
                ErrorAction      = "Stop"
            }
        
            Write-Information "SQL Query: $($createAccountSplatParams.SqlQuery | Out-String)"

            if (-Not($actionContext.DryRun -eq $true)) {
                $createAccountResponse = [System.Collections.ArrayList]::new()
                Invoke-SQLQuery @createAccountSplatParams -Data ([ref]$createAccountResponse)

                # Add AccountReference to Data
                $outputContext.Data | Add-Member -MemberType NoteProperty -Name "ExtId" -Value "$($account.ExtId)" -Force

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        # Action  = "" # Optional
                        Message = "Created staging DB record with FirstName [$($account.FirstName)] and LastName [$($account.LastName)] with AccountReference: $($outputContext.AccountReference | ConvertTo-Json)."
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would staging DB record with FirstName [$($account.FirstName)], LastName [$($account.LastName)] and ExtId [$($account.ExtId)]."
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
                $value = if ($accountNewProperty.Value -eq $null) {
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
                    $($updatePropertiesList -join ','),
                    [Action] = '$($actionContext.data.Action)',
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
                        Message = "Updated account with AccountReference: $($outputContext.AccountReference | ConvertTo-Json). Old values: $($accountChangedPropertiesObject.oldValues | ConvertTo-Json). New values: $($accountChangedPropertiesObject.newValues | ConvertTo-Json)."
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would update account with AccountReference: $($outputContext.AccountReference | ConvertTo-Json). Old values: $($accountChangedPropertiesObject.oldValues | ConvertTo-Json). New values: $($accountChangedPropertiesObject.newValues | ConvertTo-Json)."
            }
            #endregion Update account

            break
        }

        "NoChanges" {
            #region No changes
            $actionMessage = "skipping updating account"

            $outputContext.Data = $correlatedAccount.PsObject.Copy()

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    # Action  = "" # Optional
                    Message = "Skipped updating account with AccountReference: $($actionContext.References.Account | ConvertTo-Json). Reason: No changes."
                    IsError = $false
                })
            #endregion No changes

            break
        }

        "NotFound" {
            #region No account found
            $actionMessage = "updating account"

            # Throw terminal error
            throw "No account found where [$($correlationField)] = [$($correlationValue)]."
            #endregion No account found

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