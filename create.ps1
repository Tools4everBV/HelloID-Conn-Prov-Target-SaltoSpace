#Initialize default properties
$p = $person | ConvertFrom-Json
$success = $false
$auditMessage = "Account for person " + $p.DisplayName + " not created succesfully"

#Initialize SQL properties
$config = $configuration | ConvertFrom-Json
$sqlInstance = $config.connection.server
$sqlDatabaseHelloId = $config.connection.database.salto_interfaces
$sqlDatabaseSaltoSpace = $config.connection.database.salto_space
$sqlDatabaseHelloIdAccountTable = $config.connection.table.helloid_user
$sqlConnectionString = "Server=$sqlInstance;Database=$sqlDatabaseHelloId;Trusted_Connection=True;Integrated Security=true;"
$correlationAccountFieldSaltoSpace = $config.correlationAccountFieldSaltoSpace
$correlationAccountFieldSaltoStaging = $config.correlationAccountFieldSaltoStaging

#Naming convention
if(-Not([string]::IsNullOrEmpty($p.Name.FamilyNamePrefix))) { $prefix = $p.Name.FamilyNamePrefix + " " }
if(-Not([string]::IsNullOrEmpty($p.Name.FamilyNamePartnerPrefix))) { $partnerprefix = $p.Name.FamilyNamePartnerPrefix + " " }
Switch ($p.Name.Convention) {
    "B" {$surname += $prefix + $p.Name.FamilyName}
    "P" {$surname += $partnerprefix + $p.Name.FamilyNamePartner}
    "BP" {$surname += $prefix + $p.Name.FamilyName + " - " + $partnerprefix + $p.Name.FamilyNamePartner}
    "PB" {$surname += $partnerprefix + $p.Name.FamilyNamePartner + " - " + $prefix + $p.Name.FamilyName}
    default {$surname += $prefix + $p.Name.FamilyName}
}

#Most fields can only be 32 chars long...
if ($p.PrimaryContract.Department.DisplayName.length -gt 31)  {$p.PrimaryContract.Department = $p.PrimaryContract.Department.DisplayName.subString(0,31)}
if ($p.PrimaryContract.CostCenter.Name.length -gt 31)  {$p.PrimaryContract.CostCenter.Name = $p.PrimaryContract.CostCenter.Name.subString(0,31)}
if ($p.PrimaryContract.Title.Name.length -gt 31)  {$p.PrimaryContract.Title.Name = $p.PrimaryContract.Title.Name.subString(0,31)}

# Enddate
if ([string]::IsNullOrEmpty($p.PrimaryContract.EndDate)) {
    $p.PrimaryContract | Add-Member -NotePropertyName EndDate -NotePropertyValue '2099-12-01T00:00:00Z' -Force
}

try {
    $account = @{
        Action                                  = 3
        ExtUserID                               = $p.ExternalId
        FirstName                               = $p.Name.NickName
        Lastname                                = $surname # Todo: Custom veld toevoegen voor samengestelde naam!
        #Title                                  = $null
        #Office                                 = $null
        AuditOpenings                           = 1
        #ExtendedOpeningTimeEnabled             = $null
        AntipassbackEnabled                     = 1
        #CalendarID                             = $null
        GPF1                                    = $p.PrimaryContract.Department.DisplayName
        GPF2                                    = $p.ExternalId
        #GPF3                                    = $p.PrimaryContract.CostCenter.Name
        GPF3                                    = $p.Contact.Business.Address.Locality
        GPF4                                    = $p.PrimaryContract.Title.Name
        #GPF5                                   = $null
        #AutoKeyEdit_ROMCode                    = $null
        UserActivation                          = $p.PrimaryContract.StartDate
        UserExpiration_ExpDate                  = $p.PrimaryContract.EndDate
        #STKE_Period                            = $null
        #STKE_UnitOfPeriod                      = $null
    }

    $queryAccountLookupSaltoSpace = "SELECT ExtID FROM [$sqlDatabaseSaltoSpace].[dbo].[tb_Users] INNER JOIN [$sqlDatabaseSaltoSpace].[dbo].[tb_Users_Ext] ON tb_Users.id_user = tb_Users_Ext.id_user WHERE $correlationAccountFieldSaltoSpace = @$correlationAccountFieldSaltoStaging"
    $queryAccountLookupHelloId  = "SELECT ExtUserId FROM [$sqlDatabaseHelloId].[dbo].[$sqlDatabaseHelloIdAccountTable] WHERE ExtUserId = @ExtUserId"

    $queryAccountCreate = "INSERT INTO [$sqlDatabaseHelloId].[dbo].[$sqlDatabaseHelloIdAccountTable] (
                             [Action]
                            ,[ExtUserID]
                            ,[FirstName]
                            ,[Lastname]
                        --  ,[Title]
                        --  ,[Office]
                            ,[AuditOpenings]
                        --  ,[ExtendedOpeningTimeEnabled]
                            ,[AntipassbackEnabled]
                        --  ,[CalendarID]
                            ,[GPF1]
                            ,[GPF2]
                            ,[GPF3]
                            ,[GPF4]
                        --  ,[GPF5]
                        --  ,[AutoKeyEdit.ROMCode]
                            ,[UserActivation]
                            ,[UserExpiration.ExpDate]
                        --  ,[STKE.Period]
                        --  ,[STKE.UnitOfPeriod]
                            ,ToBeProcessedBySalto
                        ) VALUES (
                             @Action
                            ,@ExtUserID
                            ,@FirstName
                            ,@Lastname
                        --  ,@Title
                        --  ,@Office
                            ,@AuditOpenings
                        --  ,@ExtendedOpeningTimeEnabled
                            ,@AntipassbackEnabled
                        --  ,@CalendarID
                            ,@GPF1
                            ,@GPF2
                            ,@GPF3
                            ,@GPF4
                        --  ,@GPF5
                        --  ,@AutoKeyEdit_ROMCode
                            ,@UserActivation
                            ,@UserExpiration_ExpDate
                        --  ,@STKE_Period
                        --  ,@STKE_UnitOfPeriod
                            ,1
                        );"

    $queryAccountUpdate = "UPDATE [$sqlDatabaseHelloId].[dbo].[$sqlDatabaseHelloIdAccountTable]
                            SET
                                 [Action] = @Action
                                ,[ExtUserID] = @ExtUserID
                                ,[FirstName] = @FirstName
                            --  ,[Title] = @Title
                            --  ,[Office] = @Office
                            --   ,[ExtendedOpeningTimeEnabled] = @ExtendedOpeningTimeEnabled
                                ,[AntipassbackEnabled] = @AntipassbackEnabled
                            --  ,[CalendarID] = @CalendarID
                                ,[GPF1] = @GPF1
                                ,[GPF2] = @GPF2
                                ,[GPF3] = @GPF3
                                ,[GPF4] = @GPF4
                            --  ,[GPF5] = @GPF5
                            --  ,[AutoKeyEdit.ROMCode] = @AutoKeyEdit_ROMCode
                                ,[UserActivation] = @UserActivation
                                ,[UserExpiration.ExpDate] = @UserExpiration_ExpDate
                            --  ,[STKE.Period] = @STKE_Period
                            --  ,[STKE.UnitOfPeriod] = @STKE_UnitOfPeriod
                                ,ToBeProcessedBySalto = 1
                            WHERE ExtUserId = @ExtUserId;"

    # Connect to the SQL server
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = $sqlConnectionString
    $sqlConnection.Open()

    #Lookup record in Salto Space database (correlation)
    $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmd.Connection = $sqlConnection
    $sqlCmd.CommandText = $queryAccountLookupSaltoSpace
    $account.Keys | Foreach-Object { $null = $sqlCmd.Parameters.Add("@" + $_, "$($account.Item($_))") }
    $accountExists = $SqlCmd.ExecuteReader()
    $lookupResult = @()
    while ($accountExists.Read()) {
        for ($i = 0; $i -lt $accountExists.FieldCount; $i++) {
            $lookupResult += $accountExists.GetValue($i)
        }
    }
    $accountExists.Close()

    # Check if user already exists in the Salto Database
    write-verbose -Verbose -Message "$lookupResult"
    Switch ($lookupResult.count) {
        0 {
            Write-Verbose -Verbose -Message "Account record does not exist. Creating account record for person '$($p.displayName)' with ExtUserId '$($account.ExtUserId)'"
        }
        1 {
            $account.ExtUserID = $lookupResult[0]
            Write-Verbose -Verbose -Message "Account record exists in the Salto Space database. Correlating account record for person '$($p.displayName)' with ExtUserId '$($account.ExtUserId)'"
        }
        default {
            # TODO:"Implement audit stuff here
            throw "Multiple ($($lookupResult.count)) account records found for employeeId '$($p.externalId)' : " + ($lookupResult | convertTo-Json)
        }
    }

    # Next check if user exists in the HelloID staging table
    $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmd.Connection = $sqlConnection
    $sqlCmd.CommandText = $queryAccountLookupHelloId
    #write-verbose -verbose -Message $sqlCmd.CommandText
    $account.Keys | Foreach-Object { $null = $sqlCmd.Parameters.Add("@" + $_, "$($account.Item($_))") }
    $accountExists = $SqlCmd.ExecuteReader()
    $lookupResult = @()
    while ($accountExists.Read()) {
        for ($i = 0; $i -lt $accountExists.FieldCount; $i++) {
            $lookupResult += $accountExists.GetValue($i)
        }
    }
    $accountExists.Close()

    # Check if user already exists in the HelloID database
    Switch ($lookupResult.count) {
         0 {
            $queryAccount = $queryAccountCreate
            Write-Verbose -Verbose -Message "Account record does not exist in the HelloID database. Creating account record for person '$($p.displayName)' and ExtUserId '$($account.ExtUserId)'"
        } 1 {
            $queryAccount = $queryAccountUpdate
            Write-Verbose -Verbose -Message "Account record exists in the HelloID database. Updating account record for person '$($p.displayName)' and ExtUserId '$($account.ExtUserId)'"
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
        $sqlCmd.CommandText = $queryAccount
        $account.Keys | Foreach-Object { $null = $sqlCmd.Parameters.Add("@" + $_, "$($account.Item($_))") }
        $null = $SqlCmd.ExecuteNonQuery()
        $success = $true
        $auditMessage = "Created account record for person '$($p.displayName)' and ExtUserId '$($account.ExtUserId)' succesfully"
        Write-Verbose -Verbose -Message "Created account record for person '$($p.displayName)' and ExtUserId '$($account.ExtUserId)' succesfully"
    }
} catch {
    if (![string]::IsNullOrEmpty($_.ErrorDetails.Message)) {
        Write-Verbose -Verbose -Message "Something went wrong $($_.ScriptStackTrace). Error message: '$($_.ErrorDetails.Message)'"
        $auditMessage = "Account record not created succesfully: '$($_.ErrorDetails.Message)'"
    } else {
        Write-Verbose -Verbose -Message "Something went wrong $($_.ScriptStackTrace). Error message: '$($_)'"
        $auditMessage = "Account record not created succesfully: '$($_)'"
    }
} finally {
    $sqlConnection.Close()
}

#build up result
$result = [PSCustomObject]@{
    Success          = $success
    AccountReference = $account.ExtUserID
    AuditDetails     = $auditMessage
    Account          = $account

    # Optionally return data for use in other systems
    ExportData = [PSCustomObject]@{}
}

Write-Output $result | ConvertTo-Json -Depth 10