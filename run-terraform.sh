#!/bin/bash
set -xe  # Enable debugging (-x) and exit on error (-e)

script=$(basename "$0")

# Checking for required CLI tools
command -v aws >/dev/null 2>&1 || {  # Note: 'ls' should be 'aws' here
    echo "aws cli is not installed. Install it aws cli'."
    exit 1
}

command -v terraform >/dev/null 2>&1 || {
    echo "terraform is not installed. Install it terraform'."
    exit 1
}

# Function Definitions
function example {
    echo -e "example: $script -a init -d ./shared-services/common -e shared -r us-east-1"
}

function usage {
    echo -e "usage: $script MANDATORY [OPTION]\n"
}

function help {
    usage
    echo -e "MANDATORY:"
    echo -e "  -a  VAL  Terraform commands ( init, plan ,apply ...). Required Parameter"
    echo -e "  -d  VAL  Directory where tf files are located. Required Parameter"
    echo -e "OPTION:"
    echo -e "  -e  VAL  Environment name; defaults to dev"
    echo -e "  -p  VAL  prefix"
    echo -e "  -r  VAL  AWS region ; Defaults to us-east-1"
    echo -e "  -h       Prints this help\n"
    echo -e "  -s       Application name\n"
    example
}

# Initialize variables
BASE_DIR=$(pwd)
TF_ENV="dev"
AWS_REGION="us-east-1"
TF_AWS_REGION="us-east-1"
DRY_RUN=false
TF_PREFIX="default"

# Process command line arguments
while getopts ":a:d:e:r:p:s:" o; do
    case "${o}" in
        a) TF_ACTION=${OPTARG} ;;
        d) TF_DIR=${OPTARG} ;;
        e) TF_ENV=${OPTARG} ;;
        p) TF_PREFIX=${OPTARG} ;;
        r) TF_AWS_REGION=${OPTARG} ;;
        s) TF_APP_NAME=${OPTARG} ;;
        *) help ;;
    esac
done
shift $((OPTIND-1))

# Validate required parameters
if [ -z "${TF_ACTION}" ] || [ -z "${TF_DIR}" ] || [ -z "${TF_APP_NAME}" ]; then
    help
fi

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Set up terraform backend configuration
TF_STATE_BUCKET="$AWS_ACCOUNT_ID-terraform-state"
TF_STATE_KEY="$TF_AWS_REGION/$TF_ENV/$TF_APP_NAME/$TF_PREFIX-terraform.tfstate"
TF_DYNAMO_DB_TABLE="$AWS_ACCOUNT_ID-terraform-state-lock"

# Print configuration
echo "#################################################################"
echo " BASE_DIR                 : $BASE_DIR"
echo " TERRAFORM_DIRECTORY      : $TF_DIR"
echo " TERRAFORM_ACTION         : $TF_ACTION"
echo " TERRAFORM_ENVIRONMENT    : $TF_ENV"
echo " TERRAFORM_PREFIX         : $TF_PREFIX"
echo " TERRAFORM_STATE_BUCKET   : $TF_STATE_BUCKET"
echo " TERRAFORM_STATE_KEY      : $TF_STATE_KEY"
echo " TERRAFORM_AWS_REGION     : $TF_AWS_REGION"

# Set source directory
SRC_DIR="$TF_AWS_REGION/$TF_ENV/$TF_DIR"
if [ "$TF_ENV" = "Main" ] ; then  # Note: Fixed syntax error here (missing space)
    SRC_DIR="$TF_AWS_REGION/$TF_DIR"
fi

echo " TERRAFORM_SRC_DIR        : $SRC_DIR"
echo "################################################################"

# Initialize and run Terraform
if [ "$DRY_RUN" = false ] ; then
    echo "Initialize terraform backend"
    terraform init -reconfigure \
        -backend-config="bucket=$TF_STATE_BUCKET" \
        -backend-config="key=$TF_STATE_KEY" \
        -backend-config="dynamodb_table=$TF_DYNAMO_DB_TABLE" \
        -backend-config="region=$TF_AWS_REGION" 
fi

terraform $TF_ACTION -var-file "../tfvars/$TF_ENV/terraform.tfvars"
