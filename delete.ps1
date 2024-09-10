#Initialize default properties
$p = $person | ConvertFrom-Json
$aRef = $accountReference | ConvertFrom-Json
$success = $false
$auditMessage = "Account for person " + $p.DisplayName + " not deleted succesfully"

#Initialize SQL properties
$config = $configuration | ConvertFrom-Json
$sqlInstance = $config.connection.server
$sqlDatabaseHelloId = $config.connection.database.salto_interfaces
$sqlDatabaseHelloIdAccountTable = $config.connection.table.salto_staging
$sqlConnectionString = "Server=$sqlInstance;Database=$sqlDatabaseHelloId;Trusted_Connection=True;Integrated Security=true;"

$queryAccountLookupHelloId = "SELECT ExtUserId FROM [$sqlDatabaseHelloId].[dbo].[$sqlDatabaseHelloIdAccountTable] WHERE ExtUserId = @ExtUserId;"
$queryAccountSoftDelete = "UPDATE [$sqlDatabaseHelloId].[dbo].[$sqlDatabaseHelloIdAccountTable]  SET [Action] = @Action, [ToBeProcessedBySalto] = 1 WHERE ExtUserId = @ExtUserId;"

$account = @{
            ExtUserId = $aRef
            Action = 4
        }
Try {
    # Connect to the SQL server
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = $sqlConnectionString
    $sqlConnection.Open()

    # Next check if user exists in the HelloID staging table
    $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmd.Connection = $sqlConnection
    $sqlCmd.CommandText = $queryAccountLookupHelloId
    $account.Keys | Foreach-Object { $null = $sqlCmd.Parameters.Add("@" + $_, "$($account.Item($_))") }
    $accountExists = $SqlCmd.ExecuteReader()

    $lookupResult = @()
    while ($accountExists.Read()) {
        for ($i = 0; $i -lt $accountExists.FieldCount; $i++) {
            $lookupResult += $accountExists.GetValue($i)
        }
    }
    $accountExists.Close()

    # Check if user exists in the HelloID database
    Switch ($lookupResult.count) {
         0 {
            #$queryAccount = $queryAccountCreate
            Write-Verbose -Verbose -Message "Account record for '$($p.displayName)' with ExtUserId '$($account.ExtUserId)' does not exist in the HelloID database."
            #Mark success here!
        } 1 {
            #$queryAccount = $queryAccountUpdate
            Write-Verbose -Verbose -Message "Account record exists in the HelloID database. Soft deleting account record for person '$($p.displayName)' and ExtUserId '$($account.ExtUserId)'"
        } default {
            # TODO:"Implement audit stuff here
            throw "Multiple ($($lookupResult.count)) account records found in the HelloID database for ExtUserId '$accountReference' : " + ($lookupResult | convertTo-Json)
        }
    }

     #Do not execute when running preview
     if (-Not($dryRun -eq $True)) {

        # Run account query
        $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $sqlCmd.Connection = $sqlConnection
        $sqlCmd.CommandText = $queryAccountSoftDelete
        $account.Keys | Foreach-Object { $null = $sqlCmd.Parameters.Add("@" + $_, "$($account.Item($_))") }
        $null = $SqlCmd.ExecuteNonQuery()
        $success = $true
        $auditMessage = "Soft deleted account record for person '$($p.displayName)' and ExtUserId '$($account.ExtUserId)' succesfully"
        Write-Verbose -Verbose  -Message "Soft deleted account record for person '$($p.displayName)' and ExtUserId '$($account.ExtUserId)' succesfully"
     }
} catch {
     $auditMessage = " not deleted succesfully: General error"
     if (![string]::IsNullOrEmpty($_.ErrorDetails.Message)) {
         Write-Verbose -Verbose -Message "Something went wrong $($_.ScriptStackTrace). Error message: '$($_.ErrorDetails.Message)'"
         $auditMessage = " not deleted succesfully: '$($_.ErrorDetails.Message)'"
     } else {
         Write-Verbose -Verbose -Message "Something went wrong $($_.ScriptStackTrace). Error message: '$($_)'"
         $auditMessage = " not deleted succesfully: '$($_)'"
     }
}

#build up result
$result = [PSCustomObject]@{
    Success          = $success
    AccountReference = $accountReference
    AuditDetails     = $auditMessage
    Account          = $account

    # Optionally return data for use in other systems
    ExportData = [PSCustomObject]@{}
}

Write-Output $result | ConvertTo-Json -Depth 10