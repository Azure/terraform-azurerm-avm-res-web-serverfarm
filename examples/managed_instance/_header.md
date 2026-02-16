# Windows Managed Instance example

This deploys the module with a Windows Managed Instance App Service Plan, including:

- A user-assigned managed identity set as the plan default identity
- A storage account with a blob container containing a `scripts.zip` install script package
- The `install_scripts` property configured to pull the script from Azure Blob Storage
- A role assignment granting the managed identity `Storage Blob Data Reader` access to the storage account
