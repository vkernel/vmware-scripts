#!/bin/bash
# Validation script for NSX Security Framework multi-tenant implementation

# Set colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}NSX Security Framework Multi-Tenant Validation${NC}"
echo "============================================="

# Get list of tenants from terraform.tfvars
TENANTS=$(grep -Po '(?<=tenants = \[).*(?=\])' terraform.tfvars | tr -d '"' | tr -d ' ' | tr ',' '\n')

if [ -z "$TENANTS" ]; then
  echo -e "${RED}Error: Could not find tenants list in terraform.tfvars${NC}"
  exit 1
fi

echo -e "${YELLOW}Tenants to validate:${NC}"
for tenant in $TENANTS; do
  echo "- $tenant"
done
echo

# Validate terraform state for each tenant
echo -e "${YELLOW}Validating Terraform state...${NC}"

# Function to check for resources
check_resources() {
  tenant=$1
  resource_type=$2
  count=$(terraform state list | grep "$resource_type" | grep "\[\"$tenant\"\]" | wc -l)
  if [ $count -gt 0 ]; then
    echo -e "  - ${GREEN}✓${NC} Found $count $resource_type resources for tenant $tenant"
    return 0
  else
    echo -e "  - ${RED}✗${NC} No $resource_type resources found for tenant $tenant"
    return 1
  fi
}

# Check tenant configurations
failures=0
for tenant in $TENANTS; do
  echo -e "${YELLOW}Checking resources for tenant: $tenant${NC}"
  
  # Check for tag resources
  check_resources $tenant "module.tags" || ((failures++))
  
  # Check for group resources
  check_resources $tenant "module.groups" || ((failures++))
  
  # Check for service resources
  check_resources $tenant "module.services" || ((failures++))
  
  # Check for policy resources
  check_resources $tenant "module.policies" || ((failures++))
  
  echo
done

# Summary
if [ $failures -eq 0 ]; then
  echo -e "${GREEN}Validation successful! All tenants have resources in Terraform state.${NC}"
  echo "Note: This validation only checks Terraform state. For complete verification,"
  echo "check the NSX Manager UI or API to confirm resources are properly created."
else
  echo -e "${RED}Validation failed with $failures errors.${NC}"
  echo "Please check the terraform state and NSX Manager UI for missing resources."
fi

echo -e "\n${YELLOW}Outputs from Terraform:${NC}"
terraform output 