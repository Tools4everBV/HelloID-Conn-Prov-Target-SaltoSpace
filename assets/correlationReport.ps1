#################################################
# HelloID-Conn-Prov-Target-SaltoSpace-CorrelationReport
# PowerShell V2
#################################################

# Configuration parameters for Salto connection
$saltoConnectionString = ""
$saltoUserName = ""
$saltoPassword = ""

# Attributes used for correlating persons and accounts
$personCorrelationField = "Custom.Actuele06" # e.g., "externalId"
$accountCorrelationField = "PhoneNumber"

# Path configuration for export files
# Ensure the exportPath ends with a trailing \ in Windows or / in Unix/MacOS environments
$exportPath = "C:\HelloID\SaltoSpace\Correlation\"

# The location of the Vault export in JSON format (needs to be manually exported from a HelloID Provisioning snapshot).
$vaultJsonPath = $exportPath + "vault.json"

# Person properties to include in the report (must match exact names in Vault.json)
# ExternalId and DisplayName are included by default, so there is no need to provide them in this list
$personPropertiesToInclude = @($personCorrelationField, "Source.DisplayName") | Sort-Object -Unique

# Contract properties to include in the report (must match exact names in Vault.json)
# Contract information isn't included by default, so make sure to set this list to have insight into contract information
$contractPropertiesToInclude = @("ExternalId", "StartDate", "EndDate", "Department.DisplayName", "Department.ExternalId", "Title.Name", "Title.ExternalId", "Title.Code") | Sort-Object -Unique

# Account fields from the target system to include in the report (must match exact names in the target system)
$accountPropertiesToInclude = @("ExtId", "name", "FirstName", "LastName", "dtActivation", "dtExpiration") | Sort-Object -Unique

# Optional parameters for checking against an evaluation report
# Path to the Evaluation Report CSV (must be manually exported from a HelloID Provisioning evaluation)
# Note: If this path is empty or null, the evaluation report will not be processed
$evaluationReportCsvPath = Join-Path -Path $exportPath -ChildPath "EvaluationReport.csv"
# Name of the system to check account permission in the evaluation report (required when using the evaluation report)
$evaluationSystemName = "SaltoSpace"
# Boolean to filter for persons included in the evaluation report only
$filterPersonsInEvaluationOnly = $false

# Boolean to determine whether to use all contracts or only the primary contract
# Setting this to $true will create a record for each contract
$includeAllContracts = $false

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($actionContext.Configuration.isDebug) {
    $true { $VerbosePreference = "Continue" }
    $false { $VerbosePreference = "SilentlyContinue" }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

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
    #region Retrieve evaluation
    if (-not [string]::IsNullOrEmpty($evaluationReportCsvPath)) {
        $actionMessage = "querying data from evaluation report file"

        $evaluationReport = Import-Csv -Path $evaluationReportCsvPath -Delimiter "," -Encoding UTF8
        $evaluationPermissions = $evaluationReport | Where-Object {
            $_.System -eq $evaluationSystemName -and
            $_.Operation -eq "Grant" -and
            $_.Type -eq "Account" -and
            $_.EntitlementName -eq "Account"
        }

        Write-Information "Queried data from evaluation report file. Result count: $(($evaluationPermissions | Measure-Object).Count)"
    }
    #endregion Retrieve evalution

    #region Retrieve all persons
    $actionMessage = "querying persons from HelloID Vault file"

    $snapshot = Get-Content -Path $vaultJsonPath -Encoding UTF8 | ConvertFrom-Json
    $persons = $snapshot.Persons

    Write-Information "Queried persons from HelloID Vault file. Result count: $(($persons | Measure-Object).Count)"
    #endregion Retrieve all persons

    #region Exclude persons not in evaluation
    if ($filterPersonsInEvaluationOnly -eq $true) {
        $actionMessage = "excluding persons persons not in evaluation"

        $persons = $persons | Where-Object { $_.DisplayName -in $evaluationPermissions.Person }

        Write-Information "Excluded persons persons not in evaluation. Result count: $(($persons | Measure-Object).Count)"
    }
    #endregion Exclude persons not in evaluation

    #region Get accounts from Salto DB
    $actionMessage = "querying accounts from Salto DB"

    $getAccountsSplatParams = @{
        ConnectionString = $saltoConnectionString
        Username         = $saltoUserName
        Password         = $saltoPassword
        SqlQuery         = "
        SELECT
            *
        FROM
            [dbo].[tb_Users]
            INNER JOIN [dbo].[tb_Users_Ext] ON tb_Users.id_user = tb_Users_Ext.id_user
        "
        Verbose          = $false
        ErrorAction      = "Stop"
    }

    Write-Verbose "SQL query: $($getAccountsSplatParams.SqlQuery | Out-String)"

    $getAccountResponse = [System.Collections.ArrayList]::new()
    Invoke-SQLQuery @getAccountsSplatParams -Data ([ref]$getAccountResponse)
    $accounts = $getAccountResponse | Sort-Object -Property 'LastName'

    # Group accounts by correlation attribute to match to person
    $accountsGrouped = $null
    $accountsGrouped = $accounts | Group-Object $accountCorrelationField -AsHashTable -AsString

    Write-Information "Queried accounts from Salto DB. Result count: $(($accounts | Measure-Object).Count)"
    #endregion Get account from Salto DB

    #region Create correlated persons report
    $actionMessage = "creating correlated persons report"

    $correlatedPersons = $persons | Where-Object { ('$_.' + $personCorrelationField | Invoke-Expression) -in ('$accounts.' + $accountCorrelationField | Invoke-Expression) }
    $correlatedPersonObjects = [System.Collections.ArrayList]::new()
    foreach ($person in $correlatedPersons) {
        # Initialize the correlated person object with required fields
        $correlatedPersonObject = [PSCustomObject]@{
            PersonExternalId          = $person.ExternalId
            PersonDisplayName         = $person.DisplayName
            PersonInEvaluation        = ($person.DisplayName -in $evaluationPermissions.Person)
            PersonCorrelationField    = $personCorrelationField
            PersonCorrelationValue    = ('$person.' + $personCorrelationField | Invoke-Expression)
            AccountCorrelationWarning = $null
        }

        # Add person properties to object
        foreach ($personPropertyToInclude in $personPropertiesToInclude) {
            $correlatedPersonObject | Add-Member -MemberType NoteProperty -Name ('Person' + $personPropertyToInclude.replace(".", "")) -Value ('$person.' + $personPropertyToInclude | Invoke-Expression) -Force
        }

        # Lookup account
        $account = $accountsGrouped["$($correlatedPersonObject.PersonCorrelationValue)"]

        if (($account | Measure-Object).Count -gt 1) {
            Write-Verbose "Multiple accounts found where $($accountCorrelationField) = $($personCorrelationValue) for person $($person.DisplayName)"
        
            $correlatedPersonObject.AccountCorrelationWarning = "Multiple accounts found where $($accountCorrelationField) = $($correlatedPersonObject.PersonCorrelationValue)"

            # Skip further actions
            Continue
        }
        
        # Add account properties to object
        if ($accountPropertiesToInclude) {
            foreach ($accountPropertyToInclude in $accountPropertiesToInclude) {
                $correlatedPersonObject | Add-Member -MemberType NoteProperty -Name ('Account' + $accountPropertyToInclude.replace(".", "")) -Value ('$account.' + $accountPropertyToInclude | Invoke-Expression) -Force
            }
        }
     
        # Check whether to create a record for all contracts or just for the primary contract
        if ($includeAllContracts -eq $false) {
            $contracts = $person.PrimaryContract
        }
        else {
            $contracts = $person.Contracts
        }

        foreach ($contract in $contracts) {
            # Add contract properties to object
            if ($contractPropertiesToInclude) {
                foreach ($contractPropertyToInclude in $contractPropertiesToInclude) {
                    $correlatedPersonObject | Add-Member -MemberType NoteProperty -Name ('Contract' + $contractPropertyToInclude.replace(".", "")) -Value ('$contract.' + $contractPropertyToInclude | Invoke-Expression) -Force
                }
            }

            # Add the object to the correlated person objects list
            [void]$correlatedPersonObjects.Add($correlatedPersonObject)
        }
    }

    # Export correlated persons to csv
    $correlatedPersonObjects | Export-Csv -Path (Join-Path -Path $exportPath -ChildPath "correlatedPersons.csv") -Delimiter ";" -Encoding UTF8 -NoTypeInformation -Force
    Write-Information "Created correlated persons report. Result count: $(($correlatedPersonObjects | Measure-Object).Count)"
    #endregion Create correlated persons report

    #region Create uncorrelated persons report
    $actionMessage = "creating uncorrelated persons report"

    $uncorrelatedPersons = $persons | Where-Object { ('$_.' + $personCorrelationField | Invoke-Expression) -notin ('$accounts.' + $accountCorrelationField | Invoke-Expression) }
    $uncorrelatedPersonObjects = [System.Collections.ArrayList]::new()
    foreach ($person in $uncorrelatedPersons) {
        # Initialize the uncorrelated person object with required fields
        $uncorrelatedPersonObject = [PSCustomObject]@{
            PersonExternalId       = $person.ExternalId
            PersonDisplayName      = $person.DisplayName
            PersonInEvaluation     = ($person.DisplayName -in $evaluationPermissions.Person)
            PersonCorrelationField = $personCorrelationField
            PersonCorrelationValue = ('$person.' + $personCorrelationField | Invoke-Expression)
        }

        # Add person properties to object
        foreach ($personPropertyToInclude in $personPropertiesToInclude) {
            $uncorrelatedPersonObject | Add-Member -MemberType NoteProperty -Name ('Person' + $personPropertyToInclude.replace(".", "")) -Value ('$person.' + $personPropertyToInclude | Invoke-Expression) -Force
        }
     
        # Check whether to create a record for all contracts or just for the primary contract
        if ($includeAllContracts -eq $false) {
            $contracts = $person.PrimaryContract
        }
        else {
            $contracts = $person.Contracts
        }

        foreach ($contract in $contracts) {
            # Add contract properties to object
            if ($contractPropertiesToInclude) {
                foreach ($contractPropertyToInclude in $contractPropertiesToInclude) {
                    $uncorrelatedPersonObject | Add-Member -MemberType NoteProperty -Name ('Contract' + $contractPropertyToInclude.replace(".", "")) -Value ('$contract.' + $contractPropertyToInclude | Invoke-Expression) -Force
                }
            }

            # Add the object to the uncorrelated person objects list
            [void]$uncorrelatedPersonObjects.Add($uncorrelatedPersonObject)
        }
    }

    # Export uncorrelated persons to csv
    $uncorrelatedPersonObjects | Export-Csv -Path (Join-Path -Path $exportPath -ChildPath "uncorrelatedPersons.csv") -Delimiter ";" -Encoding UTF8 -NoTypeInformation -Force
    Write-Information "Created uncorrelated persons report. Result count: $(($uncorrelatedPersonObjects | Measure-Object).Count)"
    #endregion Create uncorrelated persons report

    #region Create uncorrelated accounts report
    $actionMessage = "creating uncorrelated accounts report"

    $uncorrelatedAccounts = $accounts | Where-Object { ('$_.' + $accountCorrelationField | Invoke-Expression) -notin ('$persons.' + $personCorrelationField | Invoke-Expression) }
    $uncorrelatedAccountObjects = [System.Collections.ArrayList]::new()
    foreach ($account in $uncorrelatedAccounts) {
        # Initialize the uncorrelated account object
        $uncorrelatedAccountObject = [PSCustomObject]@{}

        # Add account properties to object
        foreach ($accountPropertyToInclude in $accountPropertiesToInclude) {
            $uncorrelatedAccountObject | Add-Member -MemberType NoteProperty -Name ('Account' + $accountPropertyToInclude.replace(".", "")) -Value ('$account.' + $accountPropertyToInclude | Invoke-Expression) -Force
        }

        # Add the object to the uncorrelated account objects list
        [void]$uncorrelatedAccountObjects.Add($uncorrelatedAccountObject)
    }

    # Export uncorrelated accounts to csv
    $uncorrelatedAccountObjects | Export-Csv -Path (Join-Path -Path $exportPath -ChildPath "uncorrelatedAccounts.csv") -Delimiter ";" -Encoding UTF8 -NoTypeInformation -Force
    Write-Information "Created uncorrelated accounts report. Result count: $(($uncorrelatedAccountObjects | Measure-Object).Count)"
    #endregion Create uncorrelated accounts report
}
catch {
    $ex = $PSItem

    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    Write-Warning $warningMessage
    Write-Error $auditMessage
}