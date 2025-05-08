# NSX Security Framework

This Terraform project implements a robust security framework for VMware NSX environments. It creates and manages security policies, groups, services, and firewall rules based on a tenant-centric configuration model defined in YAML.

## Features

- Multi-tenancy with separate configuration per tenant
- Tag-based microsegmentation aligned with NSX best practices
- Emergency access policies for critical situations
- Environment isolation with controlled cross-environment communication
- Application-centric security policies with granular access controls
- Support for external services and communication

## Architecture

The security framework follows the concept of hierarchical security with policies implemented at different levels:

1. **Emergency Policies**: Highest priority policies for critical access
2. **Environment Policies**: Control communication between environments (e.g., Production, Test)
3. **Application Policies**: Define allowed communications between application tiers and components

## Configuration Files

Each tenant requires two YAML configuration files:

### 1. Inventory Configuration (nsx-sf-inventory.yaml)

Defines all resources (VMs, external services) organized by tenant, environment, and application tier.

```yaml
tenant_id:
  internal:
    env-{tenant}-{environment}:
      app-{tenant}-{environment}-{app}:
        app-{tenant}-{environment}-{app}-{component}:
          - vm-name-1
          - vm-name-2
  external:
    ext-{tenant}-{service}:
      - ip-address-1
  emergency:
    {tenant}-emergency:
      - vm-name-1
```

### 2. Authorized Flows Configuration (nsx-sf-authorized-flows.yaml)

Defines the allowed and blocked communication patterns between resources.

```yaml
tenant_id:
  emergency_policy:
    - name: Allow emergency rule name
      source:
        - {tenant}-emergency
      destination:
        - any
  environment_policy:
    allowed_communications:
      - name: Allow prod to test 
        source: env-{tenant}-prod
        destination: env-{tenant}-test
    blocked_communications:
      - name: Block test from prod
        source: env-{tenant}-test
        destination: env-{tenant}-prod
  application_policy:
    - name: Rule name
      source: 
        - app-{tenant}-{env}-{component1}
      destination: 
        - app-{tenant}-{env}-{component2}
      ports:
        - 443
      protocol: tcp
```

## Tagging Strategy

The framework implements a comprehensive tagging strategy:

1. **Tenant Tags**: All resources are tagged with their tenant identifier (`ten-{tenant-id}`)
2. **Environment Tags**: Resources are tagged with their environment (`env-{tenant}-{environment}`)
3. **Application Tags**: Resources are tagged with the application they belong to (`app-{tenant}-{env}-{app}`)
4. **Sub-Application Tags**: Resources are tagged with specific components within an application
5. **Emergency Tags**: Resources that need emergency access are tagged accordingly

## Groups

Based on the tagging strategy, the following security groups are created:

- Tenant groups (all resources in a tenant)
- Environment groups (all resources in an environment)
- Application groups (all resources in an application)
- Sub-application groups (all resources in a component)
- External service groups (IP-based groups for external services)
- Emergency groups (VMs that need emergency access)

## Implementation

The framework is organized into Terraform modules:

- **tags**: Creates and manages NSX tags for all resources
- **groups**: Creates NSX security groups based on tags and IP addresses
- **services**: Defines NSX services for protocol and port combinations
- **policies**: Creates security policies and firewall rules

## Usage

1. Create a directory structure for each tenant under `terraform/tenants/{tenant-id}/`
2. Create the inventory and authorized flows YAML files for each tenant
3. Add each tenant to the `tenants` list in terraform.tfvars
4. Run Terraform to apply the configuration for all tenants simultaneously:

```bash
terraform init
terraform apply
```

## Multi-Tenancy

The framework supports multiple tenants with complete isolation between them. Each tenant has:

- Separate YAML configuration files
- Dedicated security groups and policies
- Isolated firewall rules

All tenants are deployed simultaneously, allowing for multiple tenant configurations to exist without conflicts. When you run terraform apply, it will create and maintain configurations for all tenants defined in the `tenants` variable.

To create a new tenant, simply:
1. Create a new directory under `tenants/{new-tenant-id}/`
2. Create inventory.yaml and authorized-flows.yaml files for the tenant
3. Add the new tenant ID to the `tenants` list in terraform.tfvars
4. Run `terraform apply` to deploy the new tenant along with existing tenants 

## Predefined NSX Services

The following is a list of common predefined services available in NSX 4.2.1 that can be used in the `services` section of authorized-flows.yaml:

### IP Protocol Services
- ICMPv4
- ICMPv6
- IGMP
- GRE
- IPv6-ICMP
- IPv6-NoNxt
- IPv6-Opts
- OSPF

### Application Services
- Active Directory Server
- Apache Tomcat
- BGP
- CIFS
- DHCP Client
- DHCP Server
- DHCP-UDP
- DNS
- DNS-TCP
- DNS-UDP
- FTP
- HTTP
- HTTPS
- IMAP
- IMAPS
- Kerberos
- LDAP
- LDAP over SSL
- Microsoft SQL Server
- MS RPC
- MySQL
- NFS
- NTP
- OraDB
- Oracle DB SSL
- Oracle Database
- POP3
- POP3S
- PostgreSQL
- RDP
- RPC-EPMAP
- SMB
- SMB over IP
- SMTP
- SNMP
- SSH
- SSL
- Syslog
- Syslog-TCP
- Syslog-UDP
- Telnet
- TFTP
- WebDAV

## Finding Predefined Services in NSX GUI

To view all predefined services in NSX:

1. Log in to the NSX Manager UI
2. Navigate to Networking → Services → Service Definitions
3. The list will show both system-defined (predefined) services and any custom services you've created
4. You can filter the list to show only system-defined services

To use these predefined services in your authorized-flows.yaml file, add them under the `services` section:

```yaml
- name: Example rule with predefined services
  source: ext-wld09-jumphosts
  destination: app-wld09-prod-web
  services:
    - HTTPS
    - SSH
    - ICMPv4
```

This approach can be combined with the custom port/protocol definitions. When you do this, both the predefined services AND the custom port/protocol will be included in the security rule:

```yaml
- name: Example rule with custom and predefined services
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

Note: The availability of predefined services may vary between NSX versions. This list is based on NSX 4.2.1 and represents the most common services. 