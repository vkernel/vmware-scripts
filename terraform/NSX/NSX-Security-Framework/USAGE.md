# Usage Guide: NSX Security Framework Terraform Implementation

This guide provides step-by-step instructions for deploying the NSX Security Framework using Terraform.

## Prerequisites

- Terraform v1.0.0 or higher installed
- Access to an NSX Manager with valid credentials
- Virtual machines already deployed in NSX that match the names in your inventory YAML files

## Deployment Steps

### 1. Prepare Your Environment

1. Clone or download this repository to your local machine.
2. Navigate to the `terraform` directory.

### 2. Configure Tenant-Specific YAML Files

For each tenant you want to deploy:

1. Review and modify the tenant YAML files in the `tenants/<tenant_id>` directory:
   - `nsx-sf-inventory.yaml`: Defines the tenant structure (environments, applications, VMs)
   - `nsx-sf-authorized-flows.yaml`: Defines the allowed traffic flows

2. Make sure the VM names in your YAML files match the display names of your actual VMs in NSX.

### 3. Configure NSX Connection Parameters

Edit the `terraform.tfvars` file with your NSX Manager details and tenants:

```hcl
# NSX Connection Parameters
nsx_manager_host = "your-nsx-manager.example.com"
nsx_username     = "your-username"
nsx_password     = "your-password"

# Tenants to deploy simultaneously
tenants = ["wld09", "wld10"]
```

### 4. Initialize Terraform

Initialize the Terraform configuration to download the required providers:

```bash
terraform init
```

If you encounter any provider-related errors, make sure you're using the correct version of Terraform and that the NSX provider is properly specified.

### 5. Plan the Deployment

Generate and review a Terraform execution plan:

```bash
terraform plan -out=tfplan
```

This will show you what resources will be created without making any actual changes.

### 6. Apply the Configuration

Apply the Terraform configuration to create the NSX resources:

```bash
terraform apply tfplan
```

Or to plan and apply in one step:

```bash
terraform apply
```

### 7. Verify the Deployment

After Terraform completes, verify the deployment:

1. Log into your NSX Manager
2. Check that the following resources have been created:
   - VM tags for tenant, environment, application, and sub-application
   - Groups based on tags and IP addresses
   - Services for allowed protocols and ports
   - Security policies with rules for environment and application traffic

## Deploying for Multiple Tenants

The NSX Security Framework is designed to deploy configurations for multiple tenants simultaneously. All tenants specified in the `tenants` list in terraform.tfvars will be configured when you run terraform apply.

To add a new tenant:
1. Create a directory for the tenant under `tenants/<tenant_id>/`
2. Add the necessary inventory.yaml and authorized-flows.yaml files
3. Add the tenant ID to the `tenants` list in terraform.tfvars
4. Run terraform apply

To remove a tenant, simply remove it from the `tenants` list in terraform.tfvars and run terraform apply again.

## Advanced: Working with Tenants

All tenants specified in the `tenants` list are managed together and configurations for all tenants are preserved when applying changes. This allows for:

1. Multiple tenant configurations to exist without conflicts
2. Adding new tenants without affecting existing ones
3. Managing all tenant configurations through a single terraform apply operation

There is no need to use workspaces or separate state files for different tenants, as the framework now supports managing multiple tenants simultaneously in a single Terraform state.

## Modifying Existing Deployments

To modify an existing deployment:

1. Update the relevant YAML files with your changes
2. Run Terraform again:
   ```bash
   terraform apply
   ```

## Troubleshooting

### Common Issues

1. **Provider Not Found Error**:
   - Make sure you've run `terraform init`
   - Check that the provider block in `config/providers.tf` is correctly specified

2. **VM Tagging Failures**:
   - Verify that VM display names exactly match those in your YAML files
   - Check that your NSX service account has sufficient permissions

3. **Security Policy Not Working**:
   - Verify that groups are correctly created
   - Check that services are defined with correct protocols and ports
   - Ensure policies are correctly applied to the right scope

4. **YAML Parsing Errors**:
   - Ensure your YAML files are properly formatted with correct indentation
   - Validate YAML syntax using an online YAML validator

## Resource Cleanup

To remove all resources created by Terraform:

```bash
terraform destroy
```

**Caution**: This will remove all the NSX resources created by this Terraform configuration. Make sure this is what you want before confirming the destroy operation.

## Structure of authorized-flows.yaml

The `authorized-flows.yaml` file for each tenant defines the allowed traffic flows between different groups. It consists of several sections:

### Emergency Policy

The emergency policy contains rules that have the highest priority:

```yaml
emergency_policy:
  - name: Allow emergency rule on VMs with this tag
    source: emg-wld09
    destination: any
```

### Environment Policy

The environment policy controls communication between different environments (e.g., production, test, etc.):

```yaml
environment_policy:
  allowed_communications:
    - name: Allow prod environment to test environment
      source: env-wld09-prod
      destination: env-wld09-test
  blocked_communications:
    - name: Block test environment from prod environment
      source: env-wld09-test
      destination: env-wld09-prod
```

### Application Policy

The application policy defines allowed traffic between specific application components. You can specify traffic flows using two methods:

#### Method 1: Using ports and protocol

```yaml
- name: Allow web servers to application servers on port 8443
  source: 
    - app-wld09-prod-web
  destination: 
    - app-wld09-prod-application
  ports: 
    - 8443
  protocol: tcp
```

#### Method 2: Using predefined NSX services

```yaml
- name: Allow HTTPS and SSH access to web servers
  source: ext-wld09-jumphosts
  destination: 
    - app-wld09-prod-web
  services:
    - HTTPS
    - SSH
    - ICMPv4
```

#### Method 3: Combining both approaches

You can combine both approaches in the same rule. When you do this, both the predefined services AND the custom port/protocol will be included in the security rule:

```yaml
- name: Allow HTTPS and custom port access
  source: ext-wld09-jumphosts
  destination: app-wld09-prod-web
  services:
    - HTTPS
    - SSH
  ports:
    - 8443
    - 8080
  protocol: tcp
```

In this example, the rule will allow traffic using the predefined HTTPS and SSH services, plus TCP traffic on ports 8443 and 8080.

To see a list of available predefined services, refer to the Predefined NSX Services section in the README.md file. 