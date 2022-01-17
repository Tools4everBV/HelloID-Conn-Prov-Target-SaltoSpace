# HelloID-Conn-Prov-Target-SaltoSpace

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />


Connector for Salto Space, a physical access control system by Salto Systems (https://saltosystems.com)

## Getting started
### Prerequisites
- The Salto Staging table need to be setup by the customer or a Salto consultant.
- The Salto import job needs to be setup.
- The HelloID service account needs read access to the Salto Space Database.
- The HelloID service account needs read/write access to the Salto Space staging database.

### Connector settings

The following custom connector settings are available and required:

| Setting     | Description |
| ------------ | ----------- |
| SQL Server\Instance | The server\instance where the Salto Space database resides |
| Salto Space Database Name | The Salto Space database name |
| Salto & HelloID staging database name | The Salto & HelloID staging database name |
| Salto staging table name | The Salto staging table name |
| HelloID user table name | The HelloID user table name |
| HelloID membership table name | The HelloID membershp table name |
| Account correlation field in Salto Staging table | The account correlation field in the Salto Staging table |
| Account correlation Field in Salto Space database | The account correlation field in the Salto Space table |

### Supported PowerShell versions

The connector is created for Windows PowerShell 5.1. This means that the connector can not be executed in the cloud and requires an On-Premises installation of the HelloID Agent.

> Older versions of Windows PowerShell are not supported.

## Complex connector
The way this connector works is a bit complex due to the way HelloID works and how Salto expects the staging table to be filled.

- HelloID Provisioning user actions are written to the HelloID User Staging table.
- HelloID Provisioning permission actions are written to the HelloID Membership Staging table.
- A Service Automation Task is run every hour and only writes data when there's been no update to both tables within 30 minutes.
- The Service Automation Task combines both tables and merges them into the current Salto Staging table.
- In Salto Space there's a job that imports the Salto Space staging table into Salto Space.

	# HelloID Docs
	The official HelloID documentation can be found at: https://docs.helloid.com/
