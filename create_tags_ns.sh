#! /bin/bash

# Run this script to create a tag namespace and tags to use with this DPK module. 
# It uses the OCI-CLI and is designed to be run from Cloud Shell.
# If not running from Cloud Shell, set the variable OCI_TENANCY to the compartment OCID 
#   where you want the tags created.
#
# Usage: ./create_tag_ns.sh

echo "Creating 'peoplesoft' Tag Namespace"
NS_ID=$(oci iam tag-namespace create \
    --compartment-id ${OCI_TENANCY} \
    --name peoplesoft \
    --description "PeopleSoft Application Tags" \
    --wait-for-state ACTIVE | jq -r .data.id)

echo "Creating 'peoplesoft.failovergroup' Tag"
tee failovervalues.json <<EOF
{
    "validatorType": "ENUM",
    "values": [
      "pia",
      "ib",
      "none"
    ]
  }
EOF

oci iam tag create \
    --tag-namespace-id $NS_ID \
    --name failovergroup \
    --description "Failover Group" \
    --validator file://failovervalues.json

echo "Creating 'peoplesoft.tier' Tag"
tee tiervalues.json <<EOF
{
    "validatorType": "ENUM",
    "values": [
      "dmo",
      "dev",
      "tst",
      "uat",
      "sbx",
      "prd"
    ]
  }
EOF

oci iam tag create \
    --tag-namespace-id $NS_ID \
    --name tier \
    --description "Environment Tiers" \
    --validator file://tiervalues.json

echo ""
echo "Tag Namespace and Tags are ready for io_oci_facts DPK Module."
echo " - Modify the 'tier' tag values as needed."