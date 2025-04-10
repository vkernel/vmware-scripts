# NSX Microsegmentation with Terraform

This project implements NSX microsegmentation using Terraform for NSX 4.2.1.3.

## Features

- Creates NSX tags based on tenant-application pairs from VM data
- Creates environment tags
- Assigns appropriate tags to VMs
- Creates NSX groups based on tags
- Implements per-application firewall policies based on flows
- Implements environment isolation (OTAP) rules

## Prerequisites

- Terraform 1.0.0 or newer
- NSX 4.2.1.3
- VM data in CSV format
- Flow data in CSV format

## Usage

1. Clone this repository
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and update the values
3. Initialize Terraform:
   ```
   terraform init
   ```
4. Plan the deployment:
   ```
   terraform plan
   ```
5. Apply the configuration:
   ```
   terraform apply
   ```

## Input Files

- `src/vmsForVCenter_Name.csv` - VM data with tenant, environment, and application information
- `src/flows.csv` - Flow data exported from Aria Operations for Networks

## Structure

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `terraform.tfvars` - Variable values (create from example)
- `tags.tf` - NSX tag definitions
- `vm_tags.tf` - VM tag assignments
- `groups.tf` - NSX group definitions
- `firewall.tf` - Application-specific firewall policies and rules

## Notes

- The tenant-application tags are named as `tenant-application`
- The NSX groups are named as `app-tenant-application`
- Each application has its own dedicated firewall policy named `Policy-tenant-application`
- Environment isolation ensures OTAP environments are isolated from each other

## Implementation Steps

1. Identify applications within a vCenter of a specific WLD (Tenant = WLD, Application, and OTAP) based on a VM list export from vCenter. (vCenter --> VMs --> Export --> All rows)
2. Generate tags based on the output if they don't exist yet.
3. Assign VM tags in NSX based on the output
4. Create new groups based on tags using the output
5. Download known flows for each application group.
6. Generate application-specific firewall policies based on the flows

Stappen

1. Identificeer applicaties binnen een vCenter van een specifieke WLD (Tenant = WLD, Applicatie, en OTAP) op basis van een export van een VM lijst binnen vCenter. (vCenter --> VMs --> Export --> All rows)
2. Op basis van output genereer tags als die nog niet bestaan.
3. Op basis van output assign VM tags in NSX
4. Op basis van output maak nieuwe groepen aan op basis van tags
5. Download van de application groep de bekende flows.
6.

Tijdelijke changes die gemaakt zijn

1. Op de shared NSX omgeving heb ik LMBB-AZS-PRTG aan de wld09 tag toegevoegd.
2. application group aangemakt voor CTDH.
