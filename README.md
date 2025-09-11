# HelloID-Conn-Prov-Target-SaltoSpace
>
> [!WARNING]
> **Breaking Change — Field Renaming Required**
> Fields in the SaltoSpace connector have been updated.  
> Please see the [Migration](#migration) section for instructions on how to upgrade safely.  

> [!WARNING]  
> This script is for the new PowerShell connector. Make sure to use the mapping and correlation keys as described in this readme. For more information, please read our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html).

> [!IMPORTANT]  
> This repository contains only the connector and configuration code. The implementer is responsible for acquiring connection details such as the username, password, certificate, etc. You may also need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-SaltoSpace/blob/main/Logo.png?raw=true">
</p>

## Table of Contents

- [HelloID-Conn-Prov-Target-SaltoSpace](#helloid-conn-prov-target-saltospace)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported Features](#supported-features)
  - [Requirements](#requirements)
  - [Remarks](#remarks)
    - [Unique Name Requirement](#unique-name-requirement)
    - [Import Account `dtExpiration`](#import-account-dtexpiration)
    - [`dtExpiration` and `dtActivation` Fields](#dtexpiration-and-dtactivation-fields)
    - [`MobileAppType` Field](#mobileapptype-field)
    - [Staging Database Behavior](#staging-database-behavior)
  - [Getting Started](#getting-started)
    - [Salto Staging Database](#salto-staging-database)
    - [Salto Import Job](#salto-import-job)
    - [Provisioning PowerShell V2 Connector](#provisioning-powershell-v2-connector)
      - [Correlation Configuration](#correlation-configuration)
      - [Field Mapping](#field-mapping)
    - [Connection Settings](#connection-settings)
  - [Migration](#migration)
    - [Step 1: Rename fields in the SQL staging table](#step-1-rename-fields-in-the-sql-staging-table)
    - [Step 2: Update the Salto import definition](#step-2-update-the-salto-import-definition)
    - [Step 3: Disable the Salto import job temporarily](#step-3-disable-the-salto-import-job-temporarily)
  - [Getting Help](#getting-help)
  - [HelloID Docs](#helloid-docs)

## Introduction

This connector provisions accounts and permissions from HelloID into **Salto ProAccess Space** through a **staging SQL database**.  

The connector handles:  

- Account lifecycle management (create, update, enable, disable, delete, import)  
- Permission management (grant, revoke, import)  
- Synchronization via a staging table, consumed by the Salto import process

## Supported Features

The following features are available:

| Feature                                   | Supported | Actions                                 | Remarks                                                                                                                                   |
| ----------------------------------------- | --------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| **Account Lifecycle**                     | ✅         | Create, Update, Enable, Disable, Delete | Enable and Disable are managed by setting `dtActivation` and `dtExpiration`.                                                              |
| **Permissions**                           | ✅         | Retrieve, Grant, Revoke                 | Importing permissions requires adding the Permission Grant script in the 'Update action script' section.                                                               |
| **Resources**                             | ❌         | -                                       |                                                                                                                                           |
| **Entitlement Import: Accounts**          | ✅         | -                                       | After importing account entitlements, run Update Account first to prevent errors and dependency issues.|
| **Entitlement Import: Permissions**       | ✅         | -                                       | Importing permissions requires adding the Permission Grant script in the 'Update action script' section. |
| **Governance Reconciliation Resolutions** | ✅         | -                                       | Direct reconciliation actions in Salto are not supported because HelloID only manages the staging database and not the Salto Database. |

## Requirements

1. **Salto Staging SQL Database**:

- Create a dedicated SQL database (e.g. `Salto_STAGING`)  
- Run the included script `createStagingDBTable.sql` to generate the staging table  
- Grant read/write access to the HelloID service account  
- Windows Authentication recommended; SQL login possible if required.

2. **Salto Database Access**:

- Ensure HelloID has at least read access to the Salto database  
- Ideally via the HelloID service account with Windows Authentication  

3. **Salto Import Job**:
   - **Configuration**: The Salto import job needs to be set up. For detailed configuration steps, refer to the Salto Systems support guide: [Salto Import Job Setup](https://support.saltosystems.com/space/user-guide/operator/tools/creating-scheduled-jobs/#automatic-database-table-synchronization). At mapping configuration, use the same sequence as defined in ([createStagingDBTable.sql](/assets/createStagingDBTable.sql)).

4. **HelloID Concurrent Sessions**:
   - **Session Limit**: Set the maximum number of concurrent sessions in HelloID to 1. Exceeding this limit can cause unexpected issues, such as permissions being overwritten or not properly assigned.

## Remarks

### Unique Name Requirement

- The `name` field in Salto must be unique and is built from the combination of `Title`, `FirstName`, and `LastName`.
- To ensure uniqueness, it is recommended to include the employee ID in one of these fields.

### Import Account `dtExpiration`

- Importing Account Access entitlements correctly may vary depending on your Salto configuration. For example, an empty `dtExpiration` value in Salto might be stored as `01/01/2000 00:00:00` in the Salto database. Please validate the result and adjust accordingly.

```Powershell
# This setting may differ depending on your Salto configuration. Please adjust accordingly.
if ($account.dtExpiration -eq '01/01/2000 00:00:00') {
    $account.dtExpiration = $null
    $isActive = ($now -ge $dtActivation)
}
```

### `dtExpiration` and `dtActivation` Fields

- Do not manually change the values `dtExpiration` and `dtActivation`, as activation and deactivation are managed through the Account Access entitlement.

### `MobileAppType` Field

- The `MobileAppType` field is indexed starting at 0. This means the value in the staging table is always one less than the corresponding value in the Salto database. Make sure to account for this when mapping values.

### Staging Database Behavior

- Since data is written to a staging database that Salto processes independently, HelloID is not informed of any errors that occur during Salto’s processing.
- Additionally, any manual changes made directly in the Salto database will be overwritten during the next synchronization with the staging database.

## Getting Started

### Salto Staging Database

A Salto Staging database needs to be configured.

### Salto Import Job

The Salto import job needs to be configured. For detailed setup instructions, please refer to the Salto Systems support guide: [Salto Import Job Setup](https://support.saltosystems.com/space/user-guide/operator/tools/creating-scheduled-jobs/#automatic-database-table-synchronization).

If you have any questions on this, please contact your Salto representative.

### Provisioning PowerShell V2 Connector

#### Correlation Configuration

The correlation configuration specifies which properties are used to match accounts in Salto with users in HelloID.

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

#### Field Mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

### Connection Settings

| Setting                                      | Description                                                                                                                                                                                      | Mandatory |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------- |
| **Salto Database Connection string**         | The connection string used to connect to the Salto SQL database.                                                                                                                                 | Yes       |
| **Salto Staging Database Connection string** | The connection string used to connect to the Salto Staging SQL database.                                                                                                                         | Yes       |
| **Salto staging table name**                 | The name of the Salto staging table.                                                                                                                                                             | Yes       |
| **Username**                                 | Optional: The username of the SQL user to use in the connection string. Note: Not compatible with `Trusted_Connection=True` in the connection string as it requires Windows Authentication. | No        |
| **Password**                                 | Optional: The password of the SQL user to use in the connection string. Note: Not compatible with `Trusted_Connection=True` in the connection string as it requires Windows Authentication. | No        |

## Migration

If you are upgrading from an older version of this connector, the staging table must be updated to match the new field naming convention.  

### Step 1: Rename fields in the SQL staging table

| Old field name             | New field name        |
| -------------------------- | --------------------- |
| `ExtUserID`                | `ExtID`               |
| `UserActivation`           | `dtActivation`        |
| `UserExpiration.ExpDate`   | `dtExpiration`        |
| `GPF1`                     | `Dummy1`              |
| `GPF2`                     | `Dummy2`              |
| `GPF3`                     | `Dummy3`              |
| `GPF4`                     | `Dummy4`              |
| `GPF5`                     | `Dummy5`              |
| `Antipassback`             | `AntipassbackEnabled` |

### Step 2: Update the Salto import definition

Adjust the Salto import definition so that it matches the renamed fields in the staging table.  
Do not change the column order in SQL during migration; the order must remain the same as before.  
If the column order is changed, the Salto import job definition must also be updated.

### Step 3: Disable the Salto import job temporarily

During the migration, **disable the Salto import job in Salto** to prevent data inconsistencies.  
Re-enable the job once the staging table and import definition are fully updated.

---

> [!IMPORTANT]  
> Migration to this new version requires both a staging table update and import definition update.  
> Failing to do so will break connector functionality.

## Getting Help
>
> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID Docs

The official HelloID documentation can be found at: <https://docs.helloid.com/>
