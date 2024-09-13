#################################################
# HelloID-Conn-Prov-Target-SaltoSpace-Create
# PowerShell V2
#################################################
$actionContext.DryRun = $false
# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = "Continue" }
    $false { $VerbosePreference = "SilentlyContinue" }
}

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

function ConvertTo-FlatObject {
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Object,
        [string] $Prefix = ""
    )
 
    $result = [ordered]@{}
 
    foreach ($property in $Object.PSObject.Properties) {
        $name = if ($Prefix) { "$Prefix`.$($property.Name)" } else { $property.Name }
 
        #if ($null -ne $property.Value) {
            if ($property.Value -is [pscustomobject]) {
                $flattenedSubObject = ConvertTo-FlatObject -Object $property.Value -Prefix $name
                foreach ($subProperty in $flattenedSubObject.PSObject.Properties) {
                    $result[$subProperty.Name] = [string]$subProperty.Value
                }
            }
            else {
                $result[$name] = [string]$property.Value
            }
        #}
    }
    [PSCustomObject]$result
}
#endregion

try {
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.accountField
        $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }

        # Create a small lookup object to make sure the possible correlation fields are translated from the staging column names to the salto db column names
        # and get the corresponding Salto column name to do the original correlation
        $correlationMapping = @{
            'GPF1' = 'Dummy1'
            'GPF2' = 'Dummy2'
            'GPF3' = 'Dummy3'
            'GPF4' = 'Dummy4'
            'GPF5' = 'Dummy5'
            # Add more mappings as needed
        }
        if ($correlationField -in $correlationMapping.PsObject.Properties.Value) {
            $correlationFieldSaltoDb = $correlationMapping.$correlationField
        }

        # Lookup account in Salto DB and lookup the ExtUserId attribute
        $sqlQueryGetSaltoAccount = "SELECT ExtID FROM [dbo].[tb_Users] INNER JOIN [dbo].[tb_Users_Ext] ON tb_Users.id_user = tb_Users_Ext.id_user WHERE [$correlationFieldSaltoDb] = '$correlationValue'"
        Write-Verbose "Running query to find Salto Account: [$sqlQueryGetSaltoAccount]"

        $sqlQueryGetSaltoAccountResult = [System.Collections.ArrayList]::new()
        $sqlQueryGetSaltoAccountSplatParams = @{
            ConnectionString = $actionContext.Configuration.connectionStringSalto
            SqlQuery         = $sqlQueryGetSaltoAccount
            ErrorAction      = 'Stop'
        }
        Invoke-SQLQuery @sqlQueryGetSaltoAccountSplatParams -Data ([ref]$sqlQueryGetSaltoAccountResult)

        # ExtUserId = current user ExtId; we will use the correlationvalue as the unique id for new users
        $account =  ConvertTo-FlatObject -Object $outputContext.Data

        if (-not [string]::IsNullOrEmpty($sqlQueryGetSaltoAccountResult.ExtID)) {
            $account.ExtUserId = $sqlQueryGetSaltoAccountResult.ExtID

            # Get account from staging table
            $sqlQueryGetSaltoStagingAccount = "SELECT $("[" + ($account.PSObject.Properties.Name -join "],[") + "]") FROM [dbo].[$($actionContext.Configuration.dbTableStaging)] WHERE [ExtUserId] = '$($account.ExtUserId)'"
            Write-Verbose "Running query to get account in Salto Staging table: [$sqlQueryGetSaltoStagingAccount]"

            $sqlQueryGetSaltoStagingAccountResult = [System.Collections.ArrayList]::new()
            $sqlQueryGetSaltoStagingAccountSplatParams = @{
                ConnectionString = $actionContext.Configuration.connectionStringStaging
                SqlQuery         = $sqlQueryGetSaltoStagingAccount
                ErrorAction      = 'Stop'
            }

            Invoke-SQLQuery @sqlQueryGetSaltoStagingAccountSplatParams -Data ([ref]$sqlQueryGetSaltoStagingAccountResult)
            
            if ($null -eq $sqlQueryGetSaltoStagingAccountResult.ExtUserId) {
                $action = 'CreateAccount'
            } else {
                $action = 'CorrelateAccount'
                $correlatedAccount = $sqlQueryGetSaltoStagingAccountResult
            }
        } else {
            $account.ExtUserId = $correlationValue
            $action = 'CreateAccount'
        }
    }

    # Process
    switch ($action) {
        'CreateAccount' {
            # Just dump $account to table, use insert
            $sqlQueryInsertProperties = $("[" + ($account.PSObject.Properties.Name -join "],[") + "]")
            $sqlQueryInsertValues = $("'" + ($account.PSObject.Properties.Value -join "','") + "'")
            $sqlQueryAccountCreate = "INSERT INTO [dbo].[$($actionContext.Configuration.dbTableStaging)] ($sqlQueryInsertProperties) VALUES ($sqlQueryInsertValues)"

            $sqlQueryAccountCreateResult = [System.Collections.ArrayList]::new()
            $sqlQueryAccountCreateSplatParams = @{
                ConnectionString = $actionContext.Configuration.connectionStringStaging
                SqlQuery         = $sqlQueryAccountCreate
                ErrorAction      = 'Stop'
            }
            
            # Make sure to test with special characters and if needed; add utf8 encoding.
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information 'Creating and correlating SaltoSpace account'

                Invoke-SQLQuery @sqlQueryAccountCreateSplatParams -Data ([ref]$sqlQueryAccountCreateResult)

                $outputContext.Data = $account
                $outputContext.AccountReference = $account.ExtUserId
            } else {
                Write-Information '[DryRun] Create and correlate SaltoSpace account, will be executed during enforcement'
                Write-Information "Would run query [$sqlQueryAccountCreate]"
                $outputContext.Data = $account
                $outputContext.AccountReference = $account.ExtUserId
            }
            $auditLogMessage = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)]"
            break
        }

        'CorrelateAccount' {
            Write-Information 'Correlating SaltoSpace account'
            
            $outputContext.Data = $correlatedAccount
            $outputContext.AccountReference = $correlatedAccount.ExtUserId
            $outputContext.AccountCorrelated = $true
            $auditLogMessage = "Correlated account: [$($outputContext.AccountReference)] on field: [$($correlationField)] with value: [$($correlationValue)]"
            break
        }
    }
        
    $outputContext.success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $action
            Message = $auditLogMessage
            IsError = $false
        })
} catch {   
    $outputContext.success = $false
    $ex = $PSItem

    $auditMessage = "Could not create or correlate SaltoSpace account. Error: $($ex.Exception.Message)"
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}