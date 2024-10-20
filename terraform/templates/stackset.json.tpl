{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Parameters": {
    "StackName": {
      "Type": "String"
    },
    "CentralizedEventBusArn": {
      "Type": "String"
    },
    "EventBridgeRoleArn": {
      "Type": "String"
    }
  },
  "Resources": {
    "EventBridgeRule": {
      "Type": "AWS::Events::Rule",
      "Properties": {
        "Name": {
          "Ref": "StackName"
        },
        "EventPattern": ${eventPattern},
        "Targets": [
          {
            "Arn": {
              "Ref": "CentralizedEventBusArn"
            },
            "Id": {
              "Ref": "StackName"
            },
            "RoleArn": {
              "Ref": "EventBridgeRoleArn"
            }
          }
        ]
      }
    }
  }
}
