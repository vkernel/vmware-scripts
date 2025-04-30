# NSX Security Framework Terraform Implementation

This repository contains Terraform code to implement the VMware NSX Security Framework as described in the NSX_Security_Framework document. The implementation follows the principles of micro-segmentation and Zero Trust security model.

## Directory Structure

```
terraform/
├── modules/               # Reusable Terraform modules
│   ├── tags/              # VM tagging based on tenant, environment, application
│   ├── groups/            # NSX groups based on tags and IP addresses
│   ├── services/          # NSX services based on protocols and ports
│   └── policies/          # NSX security policies based on authorized flows
├── tenants/               # Tenant-specific configuration
│   ├── wld09/             # Tenant wld09 configuration
│   │   ├── nsx-sf-inventory.yaml
│   │   └── nsx-sf-authorized-flows.yaml
│   └── wld10/             # Tenant wld10 configuration
│       ├── nsx-sf-inventory.yaml
│       └── nsx-sf-authorized-flows.yaml
├── terraform.tfvars       # Global connection parameters for NSX
├── main.tf                # Main Terraform file with provider configuration
├── variables.tf           # Input variables
└── outputs.tf             # Output values
```

## Getting Started

### Prerequisites

- Terraform v1.0.0 or higher
- NSX Manager access credentials
- List of VMs to tag and group
- List of allowed flows between groups

### Deployment

1. Clone this repository
2. Navigate to the `terraform` directory
3. Edit the `terraform.tfvars` file with your NSX Manager credentials:
   ```hcl
   nsx_manager_host = "your-nsx-manager.example.com"
   nsx_username     = "your-username"
   nsx_password     = "your-password"
   tenant_id        = "wld09"  # Set which tenant to deploy
   ```
4. Initialize Terraform:
   ```bash
   terraform init
   ```
5. Apply the configuration:
   ```bash
   terraform apply
   ```

### Multi-Tenant Deployment

To deploy for a different tenant:

**Option 1: Edit the terraform.tfvars file**
```hcl
tenant_id = "wld10"  # Change to deploy a different tenant
```

**Option 2: Override on the command line**
```bash
terraform apply -var="tenant_id=wld10"
```

## YAML File Structure

### Inventory YAML (`nsx-sf-inventory.yaml`)

This file defines the tenant hierarchy structure with environments, applications, and sub-applications. It also defines external services by IP address.

```yaml
tenant:
  internal:
    environment:
      application:
        sub-application:
          - vm1
          - vm2
  external:
    service:
      - ip1
      - ip2
```

### Authorized Flows YAML (`nsx-sf-authorized-flows.yaml`)

This file defines the allowed communication flows between environments and applications.

```yaml
tenant:
  environment_policy:
    allowed_communications:
      src-env:
        - dst-env
    blocked_communications:
      src-env:
        - dst-env
  application_policy:
    - source: src-group
      destination: dst-group
      ports:
        - port
      protocol: protocol
```

## Multi-Tenant Support

The code is designed to support multiple tenants. Each tenant has its own directory with YAML configuration files. To deploy for a specific tenant, set the `tenant_id` variable in the terraform.tfvars file or override it on the command line.

## Security Framework Implementation

This Terraform code implements the following components of the NSX Security Framework:

1. **VM Tagging**: Automatically tags VMs based on their role in the tenant hierarchy (tenant, environment, application, sub-application)
2. **Dynamic Groups**: Creates NSX groups with membership criteria based on VM tags
3. **External Service Groups**: Creates groups for external services with static IP addresses
4. **Services**: Defines NSX services for allowed protocols and ports
5. **Environment Policies**: Implements environment-level security policies to control traffic between environments
6. **Application Policies**: Implements fine-grained security policies for application-specific traffic flows

The implementation follows the principle of least privilege, allowing only explicitly defined traffic flows and blocking all others by default.

See the `USAGE.md` file for detailed instructions on how to use this solution. 