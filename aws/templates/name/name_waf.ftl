[#-- Web Application Firewall --]

[#-- Resources --]

[#function formatWAFIPSetName group extensions...]
    [#return formatName(
                group,
                extensions)]
[/#function]

[#function formatComponentWAFRuleName tier component extensions...]
    [#return formatComponentFullName(
                tier,
                component,
                extensions)]
[/#function]
