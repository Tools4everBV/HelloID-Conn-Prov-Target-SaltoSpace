#################################################
# HelloID-Conn-Prov-Target-SaltoSpace-Permissions-Zones-Import
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
    $actionMessage = "querying zones from Salto DB"
    $getSaltoZonesSplatParams = @{
        ConnectionString = $actionContext.Configuration.connectionStringSalto
        Username         = $actionContext.Configuration.username
        Password         = $actionContext.Configuration.password
        SqlQuery         = "
        SELECT
            tb_Zones.Id_Zone
            ,tb_Zones.Name
            ,tb_Zones.Description
            ,tb_Zones.ExtZoneID
        FROM
            [dbo].[tb_Zones]
        ORDER BY
            Name
        "
        Verbose          = $false
        ErrorAction      = "Stop"
    }
    $getSaltoZonesResponse = [System.Collections.ArrayList]::new()
    Invoke-SQLQuery @getSaltoZonesSplatParams -Data ([ref]$getSaltoZonesResponse)
    $saltoZonesFiltered = $getSaltoZonesResponse | Where-Object { $_.Group_ExtID -ne $null -or $_.Group_ExtID -ne '' }
    Write-Information "Successfully queried [$($saltoZonesFiltered.count)] existing zones"

    $actionMessage = "querying memberships from Salto DB"
    $getSaltoMembershipsSplatParams = @{
        ConnectionString = $actionContext.Configuration.connectionStringSalto
        Username         = $actionContext.Configuration.username
        Password         = $actionContext.Configuration.password
        SqlQuery         = "
        SELECT
            tb_Users_Zones.ManagedByDBSync
            ,tb_Users_Zones.id_zone
            ,tb_Users_Ext.ExtID as User_ExtID
            ,tb_Zones.ExtZoneID as Zone_ExtID
        FROM
            tb_Users_Zones      
            INNER JOIN [dbo].[tb_Users_Ext] ON tb_Users_Ext.id_user = tb_Users_Zones.id_user
            INNER JOIN [dbo].[tb_Zones_Ext] ON tb_Zones_Ext.id_zone = tb_Users_Zones.id_zone
        "
        Verbose          = $false
        ErrorAction      = "Stop"
    }
    $getSaltoMembershipsResponse = [System.Collections.ArrayList]::new()
    Invoke-SQLQuery @getSaltoMembershipsSplatParams -Data ([ref]$getSaltoMembershipsResponse)
    $saltoMembershipsGrouped = $getSaltoMembershipsResponse | Group-Object -Property 'Group_ExtID' -AsHashTable -AsString
    Write-Information "Successfully queried [$($getSaltoMembershipsResponse.count)] existing memberships"

    foreach ($permission in $saltozoneFiltered) {
        $matchingMemberships = $saltoMembershipsGrouped[$permission.Group_ExtID].User_ExtID
        if (-not [string]::IsNullOrEmpty($matchingMemberships)) {
            Write-Output @{
                AccountReferences   = @(
                    $matchingMemberships
                )
                PermissionReference = @{
                    ExtID = $permission.Group_ExtID
                }       
                Description         = $permission.Description
                DisplayName         = $permission.Name
            }
        }
    }
    Write-Information 'Target permission import completed'
}
catch {
    $ex = $PSItem

    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    Write-Warning $warningMessage
    Write-Error $auditMessage 
}