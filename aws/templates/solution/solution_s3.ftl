[#-- S3 --]
[#if component.S3??]
    [#assign s3 = component.S3]
    [#if count > 0],[/#if]
    [#switch solutionListMode]
        [#case "definition"]
            [#-- Current bucket naming --]
            [#if s3.Name != "S3"]
                [#assign bucketName = s3.Name + segmentDomainQualifier + "." + segmentDomain]
            [#else]
                [#assign bucketName = component.Name + segmentDomainQualifier + "." + segmentDomain]
            [/#if]
            [#-- Support presence of existing s3 buckets (naming has changed over time) --]
            [#assign bucketName = getKey("s3X" + tier.Id + "X" + component.Id)!bucketName]
            "s3X${tier.Id}X${component.Id}" : {
                "Type" : "AWS::S3::Bucket",
                "Properties" : {
                    "BucketName" : "${bucketName}",
                    "Tags" : [
                        { "Key" : "cot:request", "Value" : "${requestReference}" },
                        { "Key" : "cot:configuration", "Value" : "${configurationReference}" },
                        { "Key" : "cot:tenant", "Value" : "${tenantId}" },
                        { "Key" : "cot:account", "Value" : "${accountId}" },
                        { "Key" : "cot:product", "Value" : "${productId}" },
                        { "Key" : "cot:segment", "Value" : "${segmentId}" },
                        { "Key" : "cot:environment", "Value" : "${environmentId}" },
                        { "Key" : "cot:category", "Value" : "${categoryId}" },
                        { "Key" : "cot:tier", "Value" : "${tier.Id}" },
                        { "Key" : "cot:component", "Value" : "${component.Id}" }
                    ]
                    [#if s3.Lifecycle??]
                        ,"LifecycleConfiguration" : {
                            "Rules" : [
                                {
                                    "Id" : "default",
                                    [#if s3.Lifecycle.Expiration??]
                                        "ExpirationInDays" : ${s3.Lifecycle.Expiration},
                                    [/#if]
                                    "Status" : "Enabled"
                                }
                            ]
                        }
                    [/#if]
                    [#if s3.Notifications??]
                        ,"NotificationConfiguration" : {
                        [#if s3.Notifications.SQS??]
                            "QueueConfigurations" : [
                                [#assign queueCount = 0]
                                [#list s3.Notifications.SQS?values as queue]
                                    [#if queue?is_hash]
                                        [#if queueCount > 0],[/#if]
                                        {
                                            "Event" : "s3:ObjectCreated:*",
                                            "Queue" : "${getKey("sqsX"+tier.Id+"X"+queue.Id+"Xarn")}"
                                        },
                                        {
                                            "Event" : "s3:ObjectRemoved:*",
                                            "Queue" : "${getKey("sqsX"+tier.Id+"X"+queue.Id+"Xarn")}"
                                        },
                                        {
                                            "Event" : "s3:ReducedRedundancyLostObject",
                                            "Queue" : "${getKey("sqsX"+tier.Id+"X"+queue.Id+"Xarn")}"
                                        }
                                        [#assign queueCount += 1]
                                    [/#if]
                                [/#list]
                            ]
                        [/#if]
                        }
                    [/#if]
                }
                [#if s3.Notifications??]
                    ,"DependsOn" : [
                        [#if (s3.Notifications.SQS)??]
                            [#assign queueCount = 0]
                            [#list s3.Notifications.SQS?values as queue]
                                 [#if queue?is_hash]
                                    [#if queueCount > 0],[/#if]
                                    "s3X${tier.Id}X${component.Id}X${queue.Id}Xpolicy"
                                    [#assign queueCount += 1]
                                 [/#if]
                            [/#list]
                        [/#if]
                    ]
                [/#if]
            }
            [#if (s3.Notifications.SQS)??]
                [#assign queueCount = 0]
                [#list s3.Notifications.SQS?values as queue]
                    [#if queue?is_hash]
                        ,"s3X${tier.Id}X${component.Id}X${queue.Id}Xpolicy" : {
                            "Type" : "AWS::SQS::QueuePolicy",
                            "Properties" : {
                                "PolicyDocument" : {
                                    "Version" : "2012-10-17",
                                    "Id" : "s3X${tier.Id}X${component.Id}X${queue.Id}Xpolicy",
                                    "Statement" : [
                                        {
                                            "Effect" : "Allow",
                                            "Principal" : "*",
                                            "Action" : "sqs:SendMessage",
                                            "Resource" : "*",
                                            "Condition" : {
                                                "ArnLike" : {
                                                    "aws:sourceArn" : "arn:aws:s3:::*"
                                                }
                                            }
                                        }
                                    ]
                                },
                                "Queues" : [ "${getKey("sqsX"+tier.Id+"X"+queue.Id+"Xurl")}" ]
                            }
                        }
                    [/#if]
                [/#list]
            [/#if]
            [#break]

        [#case "outputs"]
            "s3X${tier.Id}X${component.Id}" : {
                "Value" : { "Ref" : "s3X${tier.Id}X${component.Id}" }
            },
            "s3X${tier.Id}X${component.Id}Xurl" : {
                "Value" : { "Fn::GetAtt" : ["s3X${tier.Id}X${component.Id}", "WebsiteURL"] }
            }
            [#break]

    [/#switch]
    [#assign count += 1]
[/#if]