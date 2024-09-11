$config = $configuration | ConvertFrom-Json
$sqlInstance = $config.connection.server
$sqlDatabaseSaltoSpace = $config.connection.database.salto_space
$sqlConnectionString = "Server=$sqlInstance;Database=$sqlDatabaseSaltoSpace;Trusted_Connection=True;Integrated Security=true;"

$sqlQueryAccessGroupsList = 'SELECT
                groups.id_group
                ,groups.name
                ,groups.Description
                ,ext.ExtID
            FROM [dbo].[tb_Groups] AS groups
                INNER JOIN [dbo].[tb_Groups_Ext] AS ext ON groups.id_group = ext.id_group
            WHERE ext.ExtID IS NOT NULL'

try {
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = $sqlConnectionString
    $sqlConnection.Open()

    $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmd.Connection = $sqlConnection
    $sqlCmd.CommandText = $sqlQueryAccessGroupsList

    $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $sqlcmd -Verbose -Debug
    $saltoAccesGroupsTable = New-Object System.Data.DataSet
    $sqlAdapter.Fill($saltoAccesGroupsTable) | Out-Null
    foreach ($saltoAccessGroup in $saltoAccesGroupsTable.Tables[0]) {
        $permission = @{
                            DisplayName = "AG_$($saltoAccessGroup.Name)"
                            Identification = @{
                                Reference = $saltoAccessGroup.ExtID
                            }
                        }
        Write-Output ($permission | ConvertTo-Json -Depth 2)
    }
} catch {
    write-verbose -Verbose -Message $_.Exception.Message
    write-verbose -Verbose -Message ($_.InvocationInfo | convertTo-Json)
}