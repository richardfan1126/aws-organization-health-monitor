# AWS Organization Health Monitor

This project sets up an AWS Organization Health Monitor using Terraform.

It includes configurations for Slack notifications, setting alternate contacts for AWS accounts, and centralized notification using Amazon EventBridge, AWS Step Functions, and AWS Chatbot.

## Prerequisites

- Terraform
- AWS CLI configured with appropriate permissions
- Slack workspace

## Project Structure

- `slack-app-manifest.yaml`: Slack app manifest template for setting up the Slack bot.
- `config.yaml`: Configuration file for deployment regions and AWS alternate contacts for each AWS account.
- `terraform/`: Directory containing Terraform files.

## Setup Instructions

### 1. **Enable AWS Health organizational view:**

- Ensure that AWS Health organizational view is enabled in your management account.
- You can do this via the AWS Management Console. (Ref. [Enabling organizational view](https://docs.aws.amazon.com/health/latest/ug/enable-organizational-view.html))

### 2. **(Optional) Registering delegated administrator:**

- If you want to deploy this stack in a member account (i.e. not the management account), you must first delegate the account as a delegated administrator
- Follow [Registering a delegated administrator for your organizational view](https://docs.aws.amazon.com/health/latest/ug/register-a-delegated-administrator.html) for instructions

### 3. **Configure Slack App:**

- This step is to generate a Slack bot token for Terraform to manage the notification channels
   - Create a Slack app using the [`slack-app-manifest.yaml`](slack-app-manifest.yaml) file. (Ref. [Creating apps using manifests](https://api.slack.com/reference/manifests#creating_apps))
   - Install the app to your Slack workspace and retrieve the **Bot User OAuth Token** (Ref. [Installing and authorizing the app](https://api.slack.com/quickstart#installing))

### 4. **Clone the repository:**

```sh
git clone https://github.com/your-repo/aws-organization-health-monitor.git
cd aws-organization-health-monitor
```

### 5. **Update Configuration:**

- Edit the `config.yaml` file to update:
   - The Slack workspace name that you have just installed the Slack app to
   - The alternate contacts of the AWS accounts that will be configured via Terraform later

### 6. **Configure Terraform credentials:**

- Configure the following credentials for Terraform deployment:
   - Management account (or Delegated administrator account) credentials

      (Ref. http://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)
   - Slack app (Use the **Bot User OAuth Token** obtain from [Configure Slack App](#3-configure-slack-app))

      (Ref. https://registry.terraform.io/providers/pablovarela/slack/latest/docs#authentication)

### 7. **Initialize Terraform:**

```sh
cd terraform
terraform init
```

### 8. **Apply Terraform Configuration:**

```sh
terraform apply
```

## Components

### Slack Integration

- `slack.tf`: Configures Slack channels and integrates with AWS Chatbot.

### AWS Resources

- `provider.tf`: Configures AWS and Slack providers.
- `notification.tf`: Sets up SNS topics, Step Functions, and EventBridge rules.
- `data.tf`: Fetches necessary data from AWS and Slack.
- `alternate_contacts.tf`: Configures alternate contacts for AWS accounts.

### Templates

- `templates/stackset.json.tpl`: CloudFormation template for StackSet.

## License

This project is licensed under the Apache License 2.0.
