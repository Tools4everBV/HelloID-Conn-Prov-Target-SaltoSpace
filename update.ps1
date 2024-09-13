#################################################
# HelloID-Conn-Prov-Target-SaltoSpace-Update
# PowerShell V2
#################################################

$actionContext.DryRun = $false

$actionContext.References.Account = 'CE040D2C2EE640659D24B8F321A004CC'

# Set debug logging
switch ($($actionContext.Configuration.isDebug)) {
    $true { $VerbosePreference = "Continue" }
    $false { $VerbosePreference = "SilentlyContinue" }
}

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
                $result[$subProperty.Name] = [string]$subProperty.Value
            }
        }
        else {
            $result[$name] = [string]$property.Value
        }
    }
    [PSCustomObject]$result
}
#endregion

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    Write-Verbose 'Verifying if a SaltoSpace account exists'

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
    
    $outputContext.PreviousData = $correlatedAccount  
    
    # ACTION SHOULD NOT BE COMPARED! (Todo: check if this is the best place to do this)
    $correlatedAccount.PSObject.Properties.Remove('Action')
    $account.PSObject.Properties.Remove('Action')

    # DATE COMPARE MUST STILL BE FIXED

    # Always compare the account against the current account in target system
    if ($null -ne $correlatedAccount) {
        $splatCompareProperties = @{
            ReferenceObject  = @($correlatedAccount.PSObject.Properties)
            DifferenceObject = @($account.PSObject.Properties)
        }

        $propertiesChanged = Compare-Object @splatCompareProperties -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
        if ($propertiesChanged) {
            $action = 'UpdateAccount'
        } else {
            $action = 'NoChanges'
        }
    } else {
        $action = 'NotFound'
    }

    # Process
    switch ($action) {
        'UpdateAccount' {
            Write-Information "Account property(s) required to update: $($propertiesChanged.Name -join ', ')"
            $sqlQueryUpdateAccount = "UPDATE [dbo].[$($actionContext.Configuration.dbTableStaging)] SET"
            foreach ($property in $propertiesChanged) {
                $sqlQueryUpdateAccountPart = "$sqlQueryUpdateAccountPart [$($property.Name)] = '$($property.Value)', "
            }
            $sqlQueryUpdateAccount = "$sqlQueryUpdateAccount $sqlQueryUpdateAccountPart [Action] = $($actionContext.data.Action) WHERE [ExtUserId] = '$($actionContext.References.Account)'"
            Write-Verbose "Running query to update account in Salto Staging table: [$sqlQueryUpdateAccount]"
            
            # Make sure to test with special characters and if needed; add utf8 encoding. # Special chars tested (Rick)
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Updating SaltoSpace account with accountReference: [$($actionContext.References.Account)]"
                
                $sqlQueryUpdateAccountResult = [System.Collections.ArrayList]::new()
                $sqlQueryUpdateAccountSplatParams = @{
                    ConnectionString = $actionContext.Configuration.connectionStringStaging
                    SqlQuery         = $sqlQueryUpdateAccount
                    ErrorAction      = 'Stop'
                }
                Invoke-SQLQuery @sqlQueryGetAccountSplatParams -Data ([ref]$sqlQueryUpdateAccountResult)
            } else {
                Write-Information "[DryRun] Update SaltoSpace account with accountReference: [$($actionContext.References.Account)], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Update account was successful, Account property(s) updated: [$($propertiesChanged.name -join ',')]"
                    IsError = $false
                })
            break
        }

        'NoChanges' {
            Write-Information "No changes to SaltoSpace account with accountReference: [$($actionContext.References.Account)]"

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = 'No changes will be made to the account during enforcement'
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "SaltoSpace account: [$($actionContext.References.Account)] could not be found, possibly indicating that it could be deleted"
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "SaltoSpace account with accountReference: [$($actionContext.References.Account)] could not be found, possibly indicating that it could be deleted"
                    IsError = $true
                })
            break
        }
    }
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