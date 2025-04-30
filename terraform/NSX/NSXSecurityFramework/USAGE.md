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

Edit the `terraform.tfvars` file with your NSX Manager details:

```hcl
# NSX Connection Parameters
nsx_manager_host = "your-nsx-manager.example.com"
nsx_username     = "your-username"
nsx_password     = "your-password"

# Default tenant to deploy
tenant_id = "wld09"
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

You can deploy the NSX Security Framework for different tenants using the same Terraform configuration. Here are two ways to specify which tenant to deploy:

### Option 1: Edit the terraform.tfvars file

Change the `tenant_id` value in your terraform.tfvars file:

```hcl
tenant_id = "wld10"  # Change to deploy tenant wld10 instead of wld09
```

Then run:

```bash
terraform apply
```

### Option 2: Override on the command line

You can override the tenant ID without changing the terraform.tfvars file:

```bash
terraform apply -var="tenant_id=wld10"
```

## Advanced: Working with Multiple Tenants Simultaneously

If you need to manage multiple tenants simultaneously and keep their state separate:

1. Create separate workspaces for each tenant:

```bash
# Create and switch to a workspace for tenant wld09
terraform workspace new wld09
# Create and switch to a workspace for tenant wld10
terraform workspace new wld10
```

2. Switch between workspaces when deploying:

```bash
# Switch to tenant wld09
terraform workspace select wld09
terraform apply -var="tenant_id=wld09"

# Switch to tenant wld10
terraform workspace select wld10
terraform apply -var="tenant_id=wld10"
```

This approach keeps the state files separate for each tenant, allowing you to manage them independently.

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