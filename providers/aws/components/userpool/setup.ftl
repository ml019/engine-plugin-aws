[#ftl]
[#macro aws_userpool_cf_solution occurrence ]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#if deploymentSubsetRequired("genplan", false)]
        [@addDefaultGenerationPlan subsets=["prologue", "template", "epilogue", "cli"] /]
        [#return]
    [/#if]

    [#local core = occurrence.Core]
    [#local solution = occurrence.Configuration.Solution]
    [#local resources = occurrence.State.Resources]

    [#local userPoolId                 = resources["userpool"].Id]
    [#local userPoolName               = resources["userpool"].Name]

    [#local userPoolDomainId           = resources["domain"].Id]
    [#local userPoolHostName           = resources["domain"].Name]
    [#local customDomainRequired       = ((resources["customdomain"].Id)!"")?has_content ]
    [#if customDomainRequired ]
        [#local userPoolCustomDomainId = resources["customdomain"].Id ]
        [#local userPoolCustomDomainName = resources["customdomain"].Name ]
        [#local userPoolCustomDomainCertArn = resources["customdomain"].CertificateArn]
    [/#if]

    [#local smsVerification = false]
    [#local userPoolTriggerConfig = {}]
    [#local userPoolManualTriggerConfig = {}]
    [#local smsConfig = {}]
    [#local authProviders = []]

    [#local defaultUserPoolClientRequired = false ]
    [#local defaultUserPoolClientConfigured = false ]

    [#if (resources["client"]!{})?has_content]
        [#local defaultUserPoolClientRequired = true ]
        [#local defaultUserPoolClientId = resources["client"].Id]
    [/#if]

    [#local userPoolUpdateCommand = "updateUserPool" ]
    [#local userPoolClientUpdateCommand = "updateUserPoolClient" ]
    [#local userPoolDomainCommand = "setDomainUserPool" ]
    [#local userPoolAuthProviderUpdateCommand = "updateUserPoolAuthProvider" ]

    [#local emailVerificationMessage =
        getOccurrenceSettingValue(occurrence, ["UserPool", "EmailVerificationMessage"], true) ]

    [#local emailVerificationSubject =
        getOccurrenceSettingValue(occurrence, ["UserPool", "EmailVerificationSubject"], true) ]

    [#local smsVerificationMessage =
        getOccurrenceSettingValue(occurrence, ["UserPool", "SMSVerificationMessage"], true) ]

    [#local emailInviteMessage =
        getOccurrenceSettingValue(occurrence, ["UserPool", "EmailInviteMessage"], true) ]

    [#local emailInviteSubject =
        getOccurrenceSettingValue(occurrence, ["UserPool", "EmailInviteSubject"], true) ]

    [#local smsInviteMessage =
        getOccurrenceSettingValue(occurrence, ["UserPool", "SMSInviteMessage"], true) ]

    [#local smsAuthenticationMessage =
        getOccurrenceSettingValue(occurrence, ["UserPool", "SMSAuthenticationMessage"], true) ]

    [#local schema = []]
    [#list solution.Schema as key,schemaAttribute ]
        [#local schema +=  getUserPoolSchemaObject(
                            key,
                            schemaAttribute.DataType,
                            schemaAttribute.Mutable,
                            schemaAttribute.Required
        )]
    [/#list]

    [#if ((solution.MFA) || ( solution.VerifyPhone))]
        [#if ! (solution.Schema["phone_number"]!"")?has_content ]
            [@fatal
                message="Schema Attribute required: phone_number - Add Schema listed in detail"
                context=schema
                detail={
                    "phone_number" : {
                        "DataType" : "String",
                        "Mutable" : true,
                        "Required" : true
                    }
                }/]
        [/#if]

        [#local smsConfig = getUserPoolSMSConfiguration( getReference(userPoolRoleId, ARN_ATTRIBUTE_TYPE), userPoolName )]
        [#local smsVerification = true]
    [/#if]

    [#if solution.VerifyEmail || ( solution.LoginAliases.seq_contains("email"))]
        [#if ! (solution.Schema["email"]!"")?has_content ]
            [@fatal
                message="Schema Attribute required: email - Add Schema listed in detail"
                context=schema
                detail={
                    "email" : {
                        "DataType" : "String",
                        "Mutable" : true,
                        "Required" : true
                    }
                }/]
        [/#if]
    [/#if]

    [#list solution.Links?values as link]
        [#local linkTarget = getLinkTarget(occurrence, link)]

        [@debug message="Link Target" context=linkTarget enabled=false /]

        [#if !linkTarget?has_content]
            [#continue]
        [/#if]

        [#local linkTargetCore = linkTarget.Core]
        [#local linkTargetConfiguration = linkTarget.Configuration ]
        [#local linkTargetResources = linkTarget.State.Resources]
        [#local linkTargetAttributes = linkTarget.State.Attributes]

        [#switch linkTargetCore.Type]

            [#case LAMBDA_FUNCTION_COMPONENT_TYPE]

                [#-- Cognito Userpool Event Triggers --]
                [#-- TODO: When all Cognito Events are available via Cloudformation update the userPoolManualTriggerConfig to userPoolTriggerConfig --]
                [#switch link.Name?lower_case]
                    [#case "createauthchallenge"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "CreateAuthChallenge",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "custommessage"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "CustomMessage",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "defineauthchallenge"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "DefineAuthChallenge",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "postauthentication"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "PostAuthentication",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "postconfirmation"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "PostConfirmation",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "preauthentication"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "PreAuthentication",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "presignup"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "PreSignUp",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "verifyauthchallengeresponse"]
                        [#local userPoolTriggerConfig +=
                            attributeIfContent (
                                "VerifyAuthChallengeResponse",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "pretokengeneration"]
                        [#local userPoolManualTriggerConfig +=
                            attributeIfContent (
                                "PreTokenGeneration",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                    [#case "usermigration"]
                        [#local userPoolManualTriggerConfig +=
                            attributeIfContent (
                                "UserMigration",
                                linkTargetAttributes.ARN
                            )
                        ]
                        [#break]
                [/#switch]
            [#break]
        [/#switch]
    [/#list]

    [#local userPoolManualTriggerString = [] ]
    [#list userPoolManualTriggerConfig as key,value ]
        [#local userPoolManualTriggerString += [ key + "=" + value ]]
    [/#list]

    [#local userPoolManualTriggerString = userPoolManualTriggerString?join(",")]

    [#-- Initialise epilogue script with common parameters --]
    [#if deploymentSubsetRequired("epilogue", false)]
        [@addToDefaultBashScriptOutput
            content=[
                " case $\{STACK_OPERATION} in",
                "   create|update)",
                "       # Get cli config file",
                "       split_cli_file \"$\{CLI}\" \"$\{tmpdir}\" || return $?",
                "       # Get userpool id",
                "       export userPoolId=$(get_cloudformation_stack_output" +
                "       \"" + region + "\" " +
                "       \"$\{STACK_NAME}\" " +
                "       \"" + userPoolId + "\" " +
                "       || return $?)",
                "       ;;",
                " esac"
            ]
        /]
    [/#if]

    [#if ((solution.MFA) || ( solution.VerifyPhone))]
        [#if (deploymentSubsetRequired("iam", true) || deploymentSubsetRequired("userpool", true)) &&
            isPartOfCurrentDeploymentUnit(userPoolId)]

                [@createRole
                    id=userPoolRoleId
                    trustedServices=["cognito-idp.amazonaws.com"]
                    policies=
                        [
                            getPolicyDocument(
                                snsPublishPermission(),
                                "smsVerification"
                            )
                        ]
                /]
        [/#if]
    [/#if]

    [#local authProviderEpilogue = []]
    [#local userPoolClientEpilogue = []]

    [#list occurrence.Occurrences![] as subOccurrence]

        [#local subCore = subOccurrence.Core ]
        [#local subSolution = subOccurrence.Configuration.Solution ]
        [#local subResources = subOccurrence.State.Resources ]

        [#if !subSolution.Enabled]
            [#continue]
        [/#if]

        [#if subCore.Type == USERPOOL_AUTHPROVIDER_COMPONENT_TYPE ]

            [#local authProviderId = subResources["authprovider"].Id ]
            [#local authProviderName = subResources["authprovider"].Name ]
            [#local authProviderEngine = subSolution.Engine]

            [#local authProviders += [ authProviderName ]]

            [#if deploymentSubsetRequired("cli", false)]

                [#local attributeMappings = {} ]
                [#list subSolution.AttributeMappings as id, attributeMapping ]
                    [#local localAttribute = attributeMapping.UserPoolAttribute?has_content?then(
                                                attributeMapping.UserPoolAttribute,
                                                id
                    )]

                    [#local attributeMappings += {
                        localAttribute : attributeMapping.ProviderAttribute
                    }]
                [/#list]

                [#switch authProviderEngine ]
                    [#case "SAML" ]
                        [#local providerDetails = {
                            "MetadataURL" : subSolution.SAML.MetadataUrl,
                            "IDPSignout" : subSolution.SAML.EnableIDPSignOut?c
                        }]
                        [#break]
                [/#switch]

                [#local updateUserPoolAuthProvider =  {
                        "AttributeMapping" : attributeMappings,
                        "ProviderDetails" : providerDetails
                    } +
                    attributeIfContent(
                        "AttributeMapping",
                        attributeMappings
                    ) +
                    attributeIfContent(
                        "IdpIdentifiers",
                        subSolution.IDPIdentifiers
                    )
                ]

                [@addCliToDefaultJsonOutput
                    id=authProviderId
                    command=userPoolAuthProviderUpdateCommand
                    content=updateUserPoolAuthProvider
                /]
            [/#if]

            [#if deploymentSubsetRequired("epilogue", false)]
                [#local authProviderEpilogue +=
                    [
                        " case $\{STACK_OPERATION} in",
                        "   create|update)",
                        "       # Manage Userpool auth provider",
                        "       info \"Applying Cli level configuration to UserPool Auth Provider - Id: " + authProviderId +  "\"",
                        "       update_cognito_userpool_authprovider" +
                        "       \"" + region + "\" " +
                        "       \"$\{userPoolId}\" " +
                        "       \"" + authProviderName + "\" " +
                        "       \"" + authProviderEngine + "\" " +
                        "       \"$\{tmpdir}/cli-" +
                            authProviderId + "-" + userPoolAuthProviderUpdateCommand + ".json\" || return $?",
                        "       ;;",
                        " esac"
                    ]
                ]
            [/#if]
        [/#if]

        [#if subCore.Type == USERPOOL_CLIENT_COMPONENT_TYPE]

            [#if subCore.SubComponent.Id = "default" ]
                [#local defaultUserPoolClientConfigured = true]
            [/#if]

            [#local userPoolClientId           = subResources["client"].Id]
            [#local userPoolClientName         = subResources["client"].Name]

            [#local callbackUrls = []]
            [#local logoutUrls = []]
            [#local identityProviders = [ ]]

            [#list subSolution.AuthProviders as authProvider ]
                [#if authProvider?upper_case == "COGNITO" ]
                    [#local identityProviders += [ "COGNITO" ] ]
                [#else]
                    [#local linkTarget = getLinkTarget(
                                                occurrence,
                                                {
                                                    "Tier" : core.Tier.Id,
                                                    "Component" : core.Component.RawId,
                                                    "AuthProvider" : authProvider
                                                },
                                                false
                                            )]
                    [#if linkTarget?has_content ]
                        [#local identityProviders += [ linkTarget.State.Attributes["PROVIDER_NAME"] ]]
                    [/#if]
                [/#if]
            [/#list]

            [#list subSolution.Links?values as link]
                [#local linkTarget = getLinkTarget(subOccurrence, link)]

                [@debug message="Link Target" context=linkTarget enabled=false /]

                [#if !linkTarget?has_content]
                    [#continue]
                [/#if]

                [#local linkTargetCore = linkTarget.Core]
                [#local linkTargetConfiguration = linkTarget.Configuration ]
                [#local linkTargetResources = linkTarget.State.Resources]
                [#local linkTargetAttributes = linkTarget.State.Attributes]

                [#switch linkTargetCore.Type]
                    [#case LB_PORT_COMPONENT_TYPE]
                        [#local callbackUrls += [
                            linkTargetAttributes["AUTH_CALLBACK_URL"],
                            linkTargetAttributes["AUTH_CALLBACK_INTERNAL_URL"]
                            ]
                        ]
                        [#break]

                    [#case "external" ]
                        [#if linkTargetAttributes["AUTH_CALLBACK_URL"]?has_content ]
                            [#local callbackUrls += linkTargetAttributes["AUTH_CALLBACK_URL"]?split(",") ]
                        [/#if]
                        [#if linkTargetAttributes["AUTH_SIGNOUT_URL"]?has_content ]
                            [#local logoutUrls += linkTargetAttributes["AUTH_SIGNOUT_URL"]?split(",") ]
                        [/#if]
                        [#break]

                    [#case USERPOOL_AUTHPROVIDER_COMPONENT_TYPE ]
                        [#local identityProviders += [ linkTargetAttributes["PROVIDER_NAME"] ] ]
                        [#break]
                [/#switch]
            [/#list]

            [#if deploymentSubsetRequired(USERPOOL_COMPONENT_TYPE, true) ]
                [@createUserPoolClient
                    component=core.Component
                    tier=core.Tier
                    id=userPoolClientId
                    name=userPoolClientName
                    userPoolId=userPoolId
                    generateSecret=subSolution.ClientGenerateSecret
                    tokenValidity=subSolution.ClientTokenValidity
                /]
            [/#if]

            [#if deploymentSubsetRequired("cli", false)]
                [#local updateUserPoolClient =  {
                        "CallbackURLs": callbackUrls,
                        "LogoutURLs": logoutUrls,
                        "AllowedOAuthFlows": asArray(subSolution.OAuth.Flows),
                        "AllowedOAuthScopes": asArray(subSolution.OAuth.Scopes),
                        "AllowedOAuthFlowsUserPoolClient": true,
                        "SupportedIdentityProviders" : identityProviders
                    }
                ]

                [@addCliToDefaultJsonOutput
                    id=userPoolClientId
                    command=userPoolClientUpdateCommand
                    content=updateUserPoolClient
                /]
            [/#if]

            [#if deploymentSubsetRequired("epilogue", false)]
                [#local userPoolClientEpilogue +=
                    [
                        " case $\{STACK_OPERATION} in",
                        "   create|update)",
                        "       # Manage Userpool client",
                        "       info \"Applying Cli level configuration to UserPool Client - Id: " + userPoolClientId +  "\"",
                        "       export userPoolClientId=$(get_cloudformation_stack_output" +
                        "       \"" + region + "\" " +
                        "       \"$\{STACK_NAME}\" " +
                        "       \"" + userPoolClientId + "\" " +
                        "       || return $?)",
                        "       update_cognito_userpool_client" +
                        "       \"" + region + "\" " +
                        "       \"$\{userPoolId}\" " +
                        "       \"$\{userPoolClientId}\" " +
                        "       \"$\{tmpdir}/cli-" +
                            userPoolClientId + "-" + userPoolClientUpdateCommand + ".json\" || return $?",
                        "       ;;",
                        " esac"
                    ]
                ]
            [/#if]
        [/#if]

    [/#list]

    [#if defaultUserPoolClientRequired && ! defaultUserPoolClientConfigured ]
            [@fatal
                message="A default userpool client is required"
                context=solution
                detail={
                    "ActionOptions" : {
                        "1" : "Add a Client to the userpool with the id default and copy any client configuration to it",
                        "2" : "Decommission the use of the legacy client and disable DefaultClient in the solution config"
                    },
                    "context" : {
                        "DefaultClient" : defaultUserPoolClientId,
                        "DefaultClientId" : getExistingReference(defaultUserPoolClientId)
                    },
                    "Configuration" : {
                        "Clients" : {
                            "default" : {
                            }
                        }
                    }
                }
            /]
    [/#if]

    [#if deploymentSubsetRequired(USERPOOL_COMPONENT_TYPE, true) ]
        [@createUserPool
            component=core.Component
            tier=core.Tier
            id=userPoolId
            name=userPoolName
            tags=getOccurrenceCoreTags(occurrence, userPoolName)
            mfa=solution.MFA
            adminCreatesUser=solution.AdminCreatesUser
            unusedTimeout=solution.UnusedAccountTimeout
            schema=schema
            emailVerificationMessage=emailVerificationMessage
            emailVerificationSubject=emailVerificationSubject
            smsVerificationMessage=smsVerificationMessage
            smsAuthenticationMessage=smsAuthenticationMessage
            smsInviteMessage=smsInviteMessage
            emailInviteMessage=emailInviteMessage
            emailInviteSubject=emailInviteSubject
            lambdaTriggers=userPoolTriggerConfig
            autoVerify=(solution.VerifyEmail || smsVerification)?then(
                getUserPoolAutoVerification(solution.VerifyEmail, smsVerification),
                []
            )
            loginAliases=solution.LoginAliases
            passwordPolicy=getUserPoolPasswordPolicy(
                    solution.PasswordPolicy.MinimumLength,
                    solution.PasswordPolicy.Lowercase,
                    solution.PasswordPolicy.Uppsercase,
                    solution.PasswordPolicy.Numbers,
                    solution.PasswordPolicy.SpecialCharacters)
            smsConfiguration=smsConfig
        /]

    [/#if]
    [#-- When using the cli to update a user pool, any properties that are not set in the update are reset to their default value --]
    [#-- So to use the CLI to update the lambda triggers we need to generate all of the custom configuration we use in the CF template and use this as the update --]
    [#if deploymentSubsetRequired("cli", false)]

        [#local userPoolDomain = {
            "Domain" : userPoolHostName
        }]

        [@addCliToDefaultJsonOutput
            id=userPoolDomainId
            command=userPoolDomainCommand
            content=userPoolDomain
        /]

        [#if customDomainRequired]

            [#local userPoolCustomDomain = {
                "Domain" : userPoolCustomDomainName,
                "CustomDomainConfig" : {
                    "CertificateArn" : userPoolCustomDomainCertArn
                }
            }]

            [@addCliToDefaultJsonOutput
                id=userPoolCustomDomainId
                command=userPoolDomainCommand
                content=userPoolCustomDomain
            /]

        [/#if]

        [#local userpoolConfig = {
            "UserPoolId": getExistingReference(userPoolId),
            "Policies": getUserPoolPasswordPolicy(
                    solution.PasswordPolicy.MinimumLength,
                    solution.PasswordPolicy.Lowercase,
                    solution.PasswordPolicy.Uppsercase,
                    solution.PasswordPolicy.Numbers,
                    solution.PasswordPolicy.SpecialCharacters),
            "MfaConfiguration": solution.MFA?then("ON","OFF"),
            "UserPoolTags": getOccurrenceCoreTags(
                                occurrence,
                                userPoolName,
                                ""
                                false,
                                true),
            "AdminCreateUserConfig": getUserPoolAdminCreateUserConfig(
                                            solution.AdminCreatesUser,
                                            solution.UnusedAccountTimeout,
                                            getUserPoolInviteMessageTemplate(
                                                emailInviteMessage,
                                                emailInviteSubject,
                                                smsInviteMessage))
        } +
        attributeIfContent(
            "SmsVerificationMessage",
            smsVerificationMessage
        ) +
        attributeIfContent(
            "EmailVerificationMessage",
            emailVerificationMessage
        ) +
        attributeIfContent(
            "EmailVerificationSubject",
            emailVerificationSubject
        ) +
        attributeIfContent(
            "SmsConfiguration",
            smsConfig
        ) +
        attributeIfTrue(
            "AutoVerifiedAttributes",
            (solution.VerifyEmail || smsVerification),
            getUserPoolAutoVerification(solution.VerifyEmail, smsVerification)
        ) +
        attributeIfTrue(
            "LambdaConfig",
            (userPoolTriggerConfig?has_content || userPoolManualTriggerConfig?has_content ),
            userPoolTriggerConfig + userPoolManualTriggerConfig
        )]

        [#if userPoolManualTriggerConfig?has_content ]
            [@addCliToDefaultJsonOutput
                id=userPoolId
                command=userPoolUpdateCommand
                content=userpoolConfig
            /]
        [/#if]
    [/#if]

    [#if deploymentSubsetRequired("prologue", false)]
        [@addToDefaultBashScriptOutput
            content=(getExistingReference(userPoolId)?has_content)?then(
                [
                    " # Get cli config file",
                    " split_cli_file \"$\{CLI}\" \"$\{tmpdir}\" || return $?",
                    " case $\{STACK_OPERATION} in",
                    "    delete)",
                    "       # Remove All Auth providers",
                    "       info \"Removing any Auth providers\"",
                    "       cleanup_cognito_userpool_authproviders" +
                    "       \"" + region + "\" " +
                    "       \"" + getExistingReference(userPoolId) + "\" " +
                    "       \"" + authProviders?join(",") + "\" " +
                    "       \"true\" || return $?",
                    "       # Delete Userpool Domain",
                    "       info \"Removing internal userpool hosted UI Domain\"",
                    "       manage_cognito_userpool_domain" +
                    "       \"" + region + "\" " +
                    "       \"" + getExistingReference(userPoolId) + "\" " +
                    "       \"$\{tmpdir}/cli-" +
                                userPoolDomainId + "-" + userPoolDomainCommand + ".json\" \"delete\" \"internal\" || return $?"
                ] +
                (customDomainRequired)?then(
                    [
                        "       # Delete Userpool Domain",
                        "       info \"Removing custom userpool hosted UI Domain\"",
                        "       manage_cognito_userpool_domain" +
                        "       \"" + region + "\" " +
                        "       \"" + getExistingReference(userPoolId) + "\" " +
                        "       \"$\{tmpdir}/cli-" +
                                    userPoolCustomDomainId + "-" + userPoolDomainCommand + ".json\" \"delete\" \"custom\" || return $?"
                    ],
                    []
                ) +
                [
                    "       ;;",
                    " esac"
                ],
                []
            )
        /]
    [/#if]

    [#if deploymentSubsetRequired("epilogue", false)]
        [@addToDefaultBashScriptOutput
            content=
                [
                    "case $\{STACK_OPERATION} in",
                    "  create|update)"
                    "       # Adding Userpool Domain",
                    "       info \"Adding internal domain for Userpool hosted UI\"",
                    "       manage_cognito_userpool_domain" +
                    "       \"" + region + "\" " +
                    "       \"$\{userPoolId}\" " +
                    "       \"$\{tmpdir}/cli-" +
                                userPoolDomainId + "-" + userPoolDomainCommand + ".json\" \"create\" \"internal\" || return $?",
                    "       ;;",
                    " esac"
                ] +
                (customDomainRequired)?then(
                    [
                        "case $\{STACK_OPERATION} in",
                        "  create|update)"
                        "       # Adding Userpool Domain",
                        "       info \"Adding custom domain for Userpool hosted UI\"",
                        "       manage_cognito_userpool_domain" +
                        "       \"" + region + "\" " +
                        "       \"$\{userPoolId}\" " +
                        "       \"$\{tmpdir}/cli-" +
                                    userPoolCustomDomainId + "-" + userPoolDomainCommand + ".json\" \"create\" \"custom\" || return $?",
                        "       customDomainDistribution=$(get_cognito_userpool_custom_distribution" +
                        "       \"" + region + "\" " +
                        "       \"" + userPoolCustomDomainName + "\" " +
                        "       || return $?)"
                    ] +
                    pseudoStackOutputScript(
                        "UserPool Hosted UI Custom Domain CloudFront distribution",
                        {
                            formatId(userPoolCustomDomainId, DNS_ATTRIBUTE_TYPE) : "$\{customDomainDistribution}"
                        },
                        "hosted-ui"
                    ) +
                    [
                        "       ;;",
                        " esac"
                    ],
                    []
                )+
                [#-- auth providers need to be created before userpool clients are updated --]
                (authProviderEpilogue?has_content)?then(
                    authProviderEpilogue +
                    [
                        "case $\{STACK_OPERATION} in",
                        "  create|update)"
                        "       # Remove Old Auth providers",
                        "       info \"Removing old Auth providers\"",
                        "       cleanup_cognito_userpool_authproviders" +
                        "       \"" + region + "\" " +
                        "       \"" + getExistingReference(userPoolId) + "\" " +
                        "       \"" + authProviders?join(",") + "\" " +
                        "       \"false\" || return $?",
                        "       ;;",
                        "esac"
                    ],
                    []
                ) +
                (userPoolClientEpilogue?has_content)?then(
                    userPoolClientEpilogue,
                    []
                ) +
                [#-- Some Userpool Lambda triggers are not available via Cloudformation but are available via CLI --]
                (userPoolManualTriggerConfig?has_content)?then(
                    [
                        "case $\{STACK_OPERATION} in",
                        "  create|update)"
                        "       # Add Manual Cognito Triggers",
                        "       info \"Adding Cognito Triggers that are not part of cloudformation\"",
                        "       update_cognito_userpool" +
                        "       \"" + region + "\" " +
                        "       \"$\{userPoolId}\" " +
                        "       \"$\{tmpdir}/cli-" +
                                    userPoolId + "-" + userPoolUpdateCommand + ".json\" || return $?",
                        "       ;;",
                        "esac"
                    ],
                    []
                )
        /]
    [/#if]
[/#macro]