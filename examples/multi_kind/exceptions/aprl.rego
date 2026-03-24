package Azure_Proactive_Resiliency_Library_v2

import rego.v1

# FC1 (Flex Consumption) and WS1 (Workflow Standard) are specialized SKUs
# that do not fall into standard/premium/isolated tier categories.
# This exception is required for the multi_kind example which intentionally
# tests these non-standard SKU types.
exception contains rules if {
  rules = ["service_plan_use_standard_or_premium_tier"]
}
