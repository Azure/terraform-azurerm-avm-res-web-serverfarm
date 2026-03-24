package Azure_Proactive_Resiliency_Library_v2

import rego.v1

# FC1 (Flex Consumption) and WS1 (Workflow Standard) are specialized SKUs
# that do not fall into standard/premium/isolated tier categories.
# This exception is required for the multi_kind example which intentionally
# tests these non-standard SKU types.
#
# Zone redundancy is not tested in this example (it is covered by the
# complete example). The APRL zone check only applies to Premium/Isolated
# tiers, so P1v2 with zone_balancing=false would trigger it.
exception contains rules if {
  rules = ["service_plan_use_standard_or_premium_tier", "migrate_service_plan_to_availability_zone_support"]
}
