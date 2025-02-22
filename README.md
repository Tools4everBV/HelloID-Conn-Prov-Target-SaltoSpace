# HelloID-Conn-Prov-Target-SaltoSpace

> [!WARNING]
> The field names in the SaltoSpace connector have been updated. Fields previously named `GPF1`, `GPF2`, etc., are now named `Dummy1`, `Dummy2`, etc.  
> **Why?** The original `GPF` fields were renamed to match their actual system (database) names. Keeping the database field names identical in the staging table reduces the need for additional mapping in scripts.  
> This change does not affect Salto, as database fields must still be manually selected and mapped. However, please note that this update **breaks backward compatibility**. Upgrading to the latest version requires creating a new database table and reconfiguring the Salto Staging Schedule.  


> [!WARNING]
> This script is for the new powershell connector. Make sure to use the mapping and correlation keys like mentioned in this readme. For more information, please read our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html)

> [!IMPORTANT]
> This repository contains only the connector and configuration code. The implementer is responsible for acquiring connection details such as the username, password, certificate, etc. You may also need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-SaltoSpace/blob/main/Logo.png?raw=true" alt="KPN Lisa Logo">
</p>


## Table of Contents

- [HelloID-Conn-Prov-Target-SaltoSpace](#helloid-conn-prov-target-saltospace)
  - [Table of Contents](#table-of-contents)
  - [Requirements](#requirements)
  - [Remarks](#remarks)
    - [Unique Name Requirement](#unique-name-requirement)
    - [`dtExpiration` Field](#dtexpiration-field)
    - [`MobileAppType` Field](#mobileapptype-field)
    - [Staging Database Behavior](#staging-database-behavior)
  - [Introduction](#introduction)
    - [Actions](#actions)
  - [Getting Started](#getting-started)
    - [Salto Staging Database](#salto-staging-database)
    - [Salto Database Access](#salto-database-access)
    - [Salto Import Job](#salto-import-job)
    - [Provisioning PowerShell V2 connector](#provisioning-powershell-v2-connector)
      - [Correlation Configuration](#correlation-configuration)
      - [Field mapping](#field-mapping)
    - [Connection Settings](#connection-settings)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)


## Requirements

1. **Salto Staging Database**:
   - **Create a New SQL Database**: Set up a new SQL database for staging data, ideally named `Salto_STAGING`.
   - **Create the Staging Table**: Use the provided SQL script ([createStagingDBTable.sql](/assets/createStagingDBTable.sql)) to create the necessary table in the staging database.
   - **Configure Access**: Ensure both read and write access are set up for the staging database.
     - It’s recommended to use the HelloID service account with Windows authentication for enhanced security.
     - If Windows authentication isn’t available, an SQL-only user can be used, though this option offers less security.

2. **Salto Database Access**:
   - **Read Access**: Make sure read access to the Salto database is properly configured.
     - The HelloID service account with Windows authentication is preferred for stronger security.
     - If necessary, an SQL-only user can be used, though it offers lower security.

3. **Salto Import Job**:
   - **Configuration**: The Salto import job needs to be set up. For detailed configuration steps, refer to the Salto Systems support guide: [Salto Import Job Setup](https://support.saltosystems.com/space/user-guide/operator/tools/creating-scheduled-jobs/#automatic-database-table-synchronization).

4. **HelloID Concurrent Sessions**:
   - **Session Limit**: Set the maximum number of concurrent sessions in HelloID to 1. Exceeding this limit can cause unexpected issues, such as permissions being overwritten or not properly assigned.


## Remarks

### Unique Name Requirement

- The `name` field in Salto must be unique and is built from the combination of `Title`, `FirstName`, and `LastName`.
- To ensure uniqueness, it's recommended to include the employee ID in one of these fields.

### `dtExpiration` Field

- If the `dtExpiration` field is set to `null` or mapped as "none," no expiration date will be assigned to the entry.

### `MobileAppType` Field

- The `MobileAppType` field is indexed starting at 0. This means the value in the staging table is always 1 less than the corresponding value in the Salto database. Make sure to account for this when mapping values.

### Staging Database Behavior

- Since data is written to a staging database that Salto processes independently, HelloID is not informed of any errors that occur during Salto’s processing.
- Additionally, any manual changes made directly in the Salto database will be overwritten during the next synchronization with the staging database.


## Introduction

_HelloID-Conn-Prov-Target-SaltoSpace_ is a target connector that uses a staging database and a schedule in Salto Salto's REST APIs to interact with data. Below is a list of the actions provided by the connector.

### Actions

| Action                                                                                          | Description                                                                                            | Comment                                        |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| [create.ps1](create.ps1)                                                                        | Create (or update) and correlate a user account                                                        |                                                |
| [update.ps1](update.ps1)                                                                        | Update a user account                                                                                  |                                                |
| [delete.ps1](delete.ps1)                                                                        | Delete a user account                                                                                  | Be cautious; deleted users cannot be restored. |
| [permissions/accessGroups/permissions.ps1](/permissions/accessGroups/permissions.ps1)           | Retrieve all groups and provide them as entitlements                                                   |                                                |
| [permissions/accessGroups/grantPermission.ps1](/permissions/accessGroups/grantPermission.ps1)   | Add a group to a user account                                                                          |                                                |
| [permissions/accessGroups/revokePermission.ps1](/permissions/accessGroups/revokePermission.ps1) | Remove a group from a user account                                                                     |                                                |
| [permissions/accessGroups/revokePermission.ps1](/permissions/accessGroups/revokePermission.ps1) | Remove a group from a user account                                                                     |                                                |
| [assets/reports.sql](/assets/reports.sql)                                                       | SQL script to retrieve all group memberships in Salto Space and show which are not managed by HelloID. |                                                |
| [assets/createStagingDBTable.SQL](/assets/createStagingDBTable.SQL)                             | SQL script to create the staging database table.                                                       |                                                |
| [assets/correlationReport.ps1](/assets/correlationReport.ps1)                                   | Powershell script to generate a correlation report.                                                    |                                                |
| [fieldMapping.json](fieldMapping.json)                                                          | Default fieldMapping.json                                                                              |                                                |


## Getting Started

### Salto Staging Database

To use the HelloID-SaltoSpace connector, you must first set up the Salto Staging Database.

1. **Create a New SQL Database**:
   - Set up a new SQL database for the staging data. It’s recommended to use a name like `Salto_STAGING`.

2. **Create a Table**:
   - Use the SQL script provided to set up the Salto Staging table: createStagingDB.sql.

3. **Configure Access**:
   - Ensure both read and write access to the staging database are configured.
   - Preferably, use the HelloID service account with Windows authentication for enhanced security.
   - If Windows authentication is not feasible, an SQL-only user can be used, though it is less secure.

### Salto Database Access

Ensure read access to the database is configured.

- Preferably, use the HelloID service account with Windows authentication for better security.
- If Windows authentication is not possible, an SQL-only user can be used, though it is less secure.

### Salto Import Job

The Salto import job needs to be configured. For detailed setup instructions, please refer to the Salto Systems support guide: [Salto Import Job Setup](https://support.saltosystems.com/space/user-guide/operator/tools/creating-scheduled-jobs/#automatic-database-table-synchronization).

If you have any questions on this, please contact your Salto representative.


### Provisioning PowerShell V2 connector

#### Correlation Configuration
The correlation configuration specifies which properties are used to match accounts in KPN Lia with users in HelloID.

To properly set up the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                       | Value        |
    | ----------------------------- | ------------ |
    | **Person Correlation Field**  | `ExternalId` |
    | **Account Correlation Field** | `Dummy2`     |
> [!IMPORTANT]
> The **Account Correlation Field** (`Dummy2`) is just an example. Make sure to change this accordingly.

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.


#### Field mapping
The field mapping can be imported by using the _fieldMapping.json_ file.

### Connection Settings

| Setting                                      | Description                                                                                                                                                                                                                    | Mandatory |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------- |
| **Salto Database Connection string**         | The connection string used to connect to the Salto SQL database.                                                                                                                                                               | Yes       |
| **Salto Staging Database Connection string** | The connection string used to connect to the Salto Staging SQL database.                                                                                                                                                       | Yes       |
| **Salto staging table name**                 | The name of the Salto staging table.                                                                                                                                                                                           | Yes       |
| **Username**                                 | Optional: The username of the SQL user to use in the connection string. Note: This cannot be used with `Trusted_Connection=True` in the connection string as it requires Windows Authentication.                               | No        |
| **Password**                                 | Optional: The password of the SQL user to use in the connection string. Note: This cannot be used with `Trusted_Connection=True` in the connection string as it requires Windows Authentication.                               | No        |
| **Toggle Correlate Only**                    | When enabled, accounts will only be correlated, and no new accounts will be created. If no matching account is found, an error will be raised. This is useful for environments where only existing accounts should be managed. | No        |
| **Toggle debug logging**                     | Displays debug logging when toggled. **Switch off in production**                                                                                                                                                              | No        |

## Getting help
> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/
