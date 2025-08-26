#################################################
# HelloID-Conn-Prov-Target-SaltoSpace-Create
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
    $correlationField = $actionContext.CorrelationConfiguration.accountField
    $correlationValue = $actionContext.CorrelationConfiguration.personFieldValue

    # Define account object
    $account = $actionContext.Data
    # Make sure ExtID is always in $account
    if (-Not($account.PSObject.Properties.Name -Contains 'ExtID')) {
        $account | Add-Member -NotePropertyName 'ExtId' -NotePropertyValue $null -Force
    }
    #endRegion account

    #region Verify correlation configuration and properties
    $actionMessage = "verifying correlation configuration and properties"

    if ($actionContext.CorrelationConfiguration.Enabled -eq $true) {
        if ([string]::IsNullOrEmpty($correlationField)) {
            throw "Correlation is enabled but not configured correctly."
        }
        
        if ([string]::IsNullOrEmpty($correlationValue)) {
            throw "The correlation value for [$correlationField] is empty. This is likely a mapping issue."
        }
    }
    else {
        if ($actionContext.Configuration.correlateOnly -eq $true) {
            throw "Correlation is disabled while the option 'correlateOnly' is selected. Cannot continue."
        }
        else {
            Write-Warning "Correlation is disabled."
        }
    }
    #endregion Verify correlation configuration and properties

    #region Get account from Salto DB
    $actionMessage = "querying account where [$($correlationField)] = [$($correlationValue)] from Salto DB"

    $getSaltoAccountSplatParams = @{
        ConnectionString = $actionContext.Configuration.connectionStringSalto
        Username         = $actionContext.Configuration.username
        Password         = $actionContext.Configuration.password
        SqlQuery         = "
        SELECT
            tb_Users_Ext.ExtID
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
    #endregion Get account from Salto DB

 
    if (($getSaltoAccountResponse | Measure-Object).count -gt 1) {
        throw "Multiple accounts [$(($getSaltoAccountResponse | Measure-Object).count)] found where [$($correlationField)] = [$($correlationValue)] in Salto DB."
    }
    elseif (($getSaltoAccountResponse | Measure-Object).count -eq 1) {
        # Record found in Salto, check if record is available in staging
        $extIdStaging = $getSaltoAccountResponse.ExtID
    }
    else {
        # Record not found in Salto, check if HelloID ExternalID is available in staging
        $extIdStaging = $personContext.Person.ExternalId
    }

    #region Get account from Salto Staging DB
    $actionMessage = "querying account where [ExtId] = [$extIdStaging] from Salto Staging DB"
    $getSaltoStagingAccountSplatParams = @{
        ConnectionString = $actionContext.Configuration.connectionStringStaging
        Username         = $actionContext.Configuration.username
        Password         = $actionContext.Configuration.password
        SqlQuery         = "
        SELECT
            [$($account.PSObject.Properties.Name -join '],[')]
        FROM
            [dbo].[$($actionContext.Configuration.dbTableStaging)]
        WHERE
            [ExtId] = '$extIdStaging'
        "
        Verbose          = $false
        ErrorAction      = "Stop"
    }

    Write-Information "SQL Query: $($getSaltoStagingAccountSplatParams.SqlQuery | Out-String)"

    $getSaltoStagingAccountResponse = [System.Collections.ArrayList]::new()
    Invoke-SQLQuery @getSaltoStagingAccountSplatParams -Data ([ref]$getSaltoStagingAccountResponse)

    Write-Information  "Queried account where [ExtId] = [$($extIdStaging)] from Salto Staging DB. Result: $($getSaltoStagingAccountResponse | ConvertTo-Json)"
    #endregion Get account from Salto Staging DB

    $correlatedAccount = $getSaltoStagingAccountResponse
    if (($correlatedAccount | Measure-Object).count -gt 0) {
        $correlatedAccount = ConvertTo-FlatObject -Object $correlatedAccount
    }
    
    #region Calulate action
    $actionMessage = "calculating action"

    if (($correlatedAccount | Measure-Object).count -eq 1) {
        if (($getSaltoAccountResponse | Measure-Object).count -eq 1) {
            $actionAccount = "Correlate"
        }
        else {
            $actionAccount = "Create-Update"
        }
    }
    elseif (($correlatedAccount | Measure-Object).count -eq 0 -or [string]::IsNullOrEmpty($getSaltoAccountResponse.ExtId)) {
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
            $actionMessage = "creating account with FirstName [$($account.FirstName)] and LastName [$($account.LastName)]"

            # Set ExtId with ExtID of user in Salto DB, if not available, set with person externalId
            if (-not [string]::IsNullOrEmpty($getSaltoAccountResponse.ExtID)) {
                $account.ExtID = $getSaltoAccountResponse.ExtID
            }
            else {
                $account.ExtID = $personContext.Person.ExternalId
            }
            
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

                # Set AccountReference and add AccountReference to Data
                $outputContext.AccountReference = "$($account.ExtId)"
                $outputContext.Data | Add-Member -MemberType NoteProperty -Name "ExtId" -Value "$($account.ExtId)" -Force

                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        # Action  = "" # Optional
                        Message = "Created account with FirstName [$($account.FirstName)] and LastName [$($account.LastName)] with AccountReference: $($outputContext.AccountReference | ConvertTo-Json)."
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would create account with FirstName [$($account.FirstName)], LastName [$($account.LastName)] and ExtId [$($account.ExtId)]."
            }
            #endregion Create account

            break
        }

        "Create-Update" {
            #region Update account
            $actionMessage = "create-updating account with AccountReference: $($correlatedAccount.ExtId | ConvertTo-Json)" 
            $outputContext.AccountReference = "$($correlatedAccount.ExtId)"  

            # Create a list of properties to update
            $updatePropertiesList = [System.Collections.Generic.List[string]]::new()
            $accountNewProperties = $account | Select-Object -ExcludeProperty 'ExtId'
            Write-Warning "$($accountNewProperties | ConvertTo-Json)"
            foreach ($accountNewProperty in $accountNewProperties.PSObject.Properties) {
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
                    [ExtId] = '$($correlatedAccount.ExtId)'
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
                        Message = "Created account with FirstName [$($account.FirstName)] and LastName [$($account.LastName)] with AccountReference: $($outputContext.AccountReference | ConvertTo-Json). Updated staging DB."
                        IsError = $false
                    })
            }
            else {
                Write-Warning "DryRun: Would create account with FirstName [$($account.FirstName)] and LastName [$($account.LastName)] with AccountReference: $($outputContext.AccountReference | ConvertTo-Json). Would update staging DB."
            }
            #endregion Update account

            break
        }

        "Correlate" {
            #region Correlate account
            $actionMessage = "correlating to account"

            # Set AccountReference and add AccountReference to Data
            $outputContext.AccountReference = "$($correlatedAccount.ExtId)"       
            $outputContext.Data | Add-Member -MemberType NoteProperty -Name "ExtId" -Value "$($correlatedAccount.ExtId)" -Force

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = "CorrelateAccount" # Optionally specify a different action for this audit log
                    Message = "Correlated to account with AccountReference: $($outputContext.AccountReference | ConvertTo-Json) on [$($correlationField)] = [$($correlationValue)]."
                    IsError = $false
                })

            $outputContext.AccountCorrelated = $true
            #endregion Correlate account

            break
        }

        "MultipleFound" {
            #region Multiple accounts found
            $actionMessage = "correlating to account"

            # Throw terminal error
            throw "Multiple accounts found where [$($correlationField)] = [$($correlationValue)]. Please ensure each person has a unique identifier."
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
            # Action= "" # Optional
            Message = $auditMessage
            IsError = $true
        })
}
finally {
    # Check if auditLogs contains errors, if no errors are found, set success to true
    if (-NOT($outputContext.AuditLogs.IsError -contains $true)) {
        $outputContext.Success = $true
    }

    # Check if accountReference is set, if not set, set this with default value as this must contain a value
    if ([String]::IsNullOrEmpty($outputContext.AccountReference) -and $actionContext.DryRun -eq $true) {
        $outputContext.AccountReference = "DryRun: Currently not available"
    }
}