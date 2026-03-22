# Multi-kind example

This example deploys multiple App Service Plans with different SKU kinds to verify that the module correctly handles the `kind` property for each SKU type without configuration drift.

The following plan types are tested:

- **Standard (S1)**: Linux, kind = `"linux"`
- **Premium (P1v2)**: Windows, kind = `"windows"`
- **Flex Consumption (FC1)**: Linux, kind = `"functionapp"`, capacity managed by Azure
- **Workflow Standard (WS1)**: Windows, kind = `"elastic"`, elasticScaleEnabled forced true
