Get-DatastoreCluster | select `
Name,
sdrsautomationlevel,
SpaceUtilizationThresholdPercent,
@{n='MinSpaceUtilizationDifference';e={$_.ExtensionData.podstoragedrsentry.storagedrsconfig.podconfig.spaceloadbalanceconfig.minspaceutilizationdifference}},
IOLoadBalanceEnabled,
IOLatencyThresholdMillisecond,
@{n='LoadBalanceInterval';e={$_.ExtensionData.podstoragedrsentry.storagedrsconfig.podconfig.loadbalanceinterval}},
@{n='IoLoadImbalanceThreshold';e={$_.ExtensionData.podstoragedrsentry.storagedrsconfig.podconfig.IOLoadBalanceConfig.ioloadimbalancethreshold}},
@{n='DefaultIntraVmAffinity';e={$_.ExtensionData.podstoragedrsentry.storagedrsconfig.podconfig.DefaultIntraVmAffinity}},
@{n='SpaceLoadBalanceAutomationMode';e={$_.ExtensionData.podstoragedrsentry.storagedrsconfig.podconfig.automationoverrides.SpaceLoadBalanceAutomationMode}},
@{n='IoLoadBalanceAutomationMode';e={$_.ExtensionData.podstoragedrsentry.storagedrsconfig.podconfig.automationoverrides.IoLoadBalanceAutomationMode}},
@{n='RuleEnforcementAutomationMode';e={$_.ExtensionData.podstoragedrsentry.storagedrsconfig.podconfig.automationoverrides.RuleEnforcementAutomationMode}},
@{n='PolicyEnforcementAutomationMode';e={$_.ExtensionData.podstoragedrsentry.storagedrsconfig.podconfig.automationoverrides.PolicyEnforcementAutomationMode}}