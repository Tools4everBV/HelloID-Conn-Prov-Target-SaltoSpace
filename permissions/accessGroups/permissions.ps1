#################################################
# HelloID-Conn-Prov-Target-SaltoSpace-Permissions-Groups-List
# List groups as permissions
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
#endregion

try {
    #region Get Groups
    $actionMessage = "querying groups"

    $getSaltoGroupsSplatParams = @{
        ConnectionString = $actionContext.Configuration.connectionStringSalto
        Username         = $actionContext.Configuration.username
        Password         = $actionContext.Configuration.password
        SqlQuery         = "
        SELECT
            tb_Groups.Id_Group
            ,tb_Groups.Name
            ,tb_Groups.Description
            ,tb_Groups_Ext.ExtID
        FROM
            [dbo].[tb_Groups]
            INNER JOIN [dbo].[tb_Groups_Ext] ON tb_Groups.id_group = tb_Groups_Ext.id_group
        "
        Verbose          = $false
        ErrorAction      = "Stop"
    }

    Write-Information "SQL Query: $($getSaltoGroupsSplatParams.SqlQuery | Out-String)"
    
    $getSaltoGroupsResponse = [System.Collections.ArrayList]::new()
    Invoke-SQLQuery @getSaltoGroupsSplatParams -Data ([ref]$getSaltoGroupsResponse)
    $saltoGroups = $getSaltoGroupsResponse

    Write-Information "Queried groups. Result count: $(($saltoGroups | Measure-Object).Count)"
    #endregion Get Groups

    #region Send results to HelloID
    $saltoGroups | ForEach-Object {
        # Shorten DisplayName to max. 100 chars
        $displayName = "Group - $($_.name)"
        $displayName = $displayName.substring(0, [System.Math]::Min(100, $displayName.Length))

        $outputContext.Permissions.Add(
            @{
                displayName    = $displayName
                identification = @{
                    ExtID       = $_.ExtID
                }
            }
        )
    }
    #endregion Send results to HelloID
}
catch {
    $ex = $PSItem

    $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"

    Write-Warning $warningMessage

    # Required to write an error as the listing of permissions doesn't show auditlog
    Write-Error $auditMessage
}