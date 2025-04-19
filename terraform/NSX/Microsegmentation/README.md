# NSX Microsegmentation Terraform

This Terraform project automates the implementation of microsegmentation policies in VMware NSX-T environments. It creates security policies, groups, and firewall rules based on application components and communication patterns defined in YAML configuration files.

## Features

- YAML-based configuration of virtual machines, applications, and environments
- Dynamic generation of NSX-T groups based on VM tags and application tiers
- Automatic creation of security policies and firewall rules from allowed flows definitions
- Environment isolation with configurable inter-environment communications
- Support for external entity definitions (e.g., DNS, NTP services)

## Prerequisites

- Terraform 1.0.0 or newer
- NSX-T 3.0 or newer
- NSX-T Manager with appropriate credentials

## Configuration Files

The project uses the following YAML files for configuration:

- `src/VMs.yaml`: Defines VMs organized by tenant, environment, and application tier
- `src/allowed_flows.yaml`: Defines allowed communications between application tiers

### VMs.yaml Structure

```yaml
tenant:
  allowed_communications:  # Optional section to define environment communications
    Environment1:
      - Environment2
  Environment1:
    ApplicationTier1:
      - vm-name-1
      - vm-name-2
    ApplicationTier2:
      - vm-name-3
  Environment2:
    ApplicationTier1:
      - vm-name-4
  External:  # Optional section to define external IP addresses or services
    Service1:
      - ip-address-1
```

### allowed_flows.yaml Structure

```yaml
tenant:
  - source: ApplicationTier1
    destination: ApplicationTier2
    ports:
      - 80
      - 443
    protocol: tcp
  
  - source: 
      - ApplicationTier1
      - ApplicationTier2
    destination: ExternalService
    ports:
      - 53
    protocol: udp
```

## Usage

1. Configure your NSX-T connection parameters in `terraform.tfvars`:

```hcl
nsx_manager  = "nsx.example.com"
nsx_username = "admin"
nsx_password = "password"
```

2. Define your virtual machines and applications in `src/VMs.yaml`

3. Define allowed communications in `src/allowed_flows.yaml`

4. Initialize and apply the Terraform configuration:

```bash
terraform init
terraform plan
terraform apply
```

## Resources Created

This Terraform configuration creates:

- NSX-T groups for environments, application tiers, and external entities
- VM tags for microsegmentation
- Security policies for application communications
- Environment isolation policies
- Custom services for protocol/port combinations
- Firewall rules based on allowed flows

## Outputs

The project provides outputs for the created resources, making it easier to reference them in other configurations or for documentation purposes.

## Notes

- The configuration supports a single tenant structure
- All security policies have logging enabled by default
- The default action for undefined traffic is to drop (deny) 