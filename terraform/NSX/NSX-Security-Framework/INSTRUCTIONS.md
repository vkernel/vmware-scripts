# NSX Security Framework Multi-Tenant Instructions

This document explains how to use the updated NSX Security Framework that now supports simultaneous deployment of multiple tenant configurations.

## Key Changes

1. The framework now supports deploying configurations for multiple tenants simultaneously
2. No more deletion of tenant configurations when switching between tenants
3. All tenant configurations are preserved when applying changes
4. Added a `tenants` variable that accepts a list of tenant IDs

## How to Use

### 1. Setup Tenant Configurations

For each tenant you want to deploy:

1. Create a directory under `tenants/{tenant_id}/`
2. Create or modify `inventory.yaml` with the tenant's resources
3. Create or modify `authorized-flows.yaml` with the tenant's allowed traffic

### 2. Configure Tenants List

Edit the `terraform.tfvars` file and set the list of tenants to deploy:

```hcl
# NSX Connection Parameters
nsx_manager_host = "nsx01.lab.lan"
nsx_username     = "admin"
nsx_password     = "VMware1!VMware1!"

# List of tenants to deploy simultaneously
tenants = ["wld09", "wld10"]
```

### 3. Apply Configuration

Run terraform to apply configurations for all tenants:

```bash
terraform init
terraform apply
```

### 4. Managing Tenants

#### Adding a New Tenant

1. Create the tenant directory and YAML files
2. Add the tenant ID to the `tenants` list
3. Run `terraform apply`

#### Removing a Tenant

1. Remove the tenant ID from the `tenants` list
2. Run `terraform apply`

#### Modifying a Tenant

1. Update the tenant's YAML files
2. Run `terraform apply`

## Validation Steps

After applying the configuration, verify that:

1. Tags are created for all tenants
2. Groups are created for all tenants
3. Services are created for all tenants
4. Policies and rules are created for all tenants

You can check these in the NSX Manager UI or use the following terraform command to see the outputs:

```bash
terraform output
```

## Troubleshooting

### Common Issues

1. **YAML parsing errors**: Ensure your YAML files are properly formatted
2. **Missing tenant configurations**: Verify that both inventory.yaml and authorized-flows.yaml exist for each tenant
3. **NSX API errors**: Check that the NSX Manager is accessible and credentials are correct

### Logs

If you encounter issues, enable Terraform debug logging:

```bash
export TF_LOG=DEBUG
terraform apply > terraform.log
```

## Best Practices

1. Keep tenant configurations separate in the tenant directories
2. Use consistent naming conventions across all tenants
3. Test changes in a non-production environment first
4. Always review the terraform plan before applying changes 