#!/bin/bash

# setup-backend.sh
set -e

# Function to validate AWS CLI and credentials
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI is not installed"
        exit 1
    fi

    if ! aws sts get-caller-identity &> /dev/null; then
        echo "Error: AWS credentials not configured or invalid"
        exit 1
    fi
    }



# Create backend resources
create_backend_resources() {
    local account_id="$1"
    local region="$2"
    local bucket_name="${account_id}-terraform-state"
    local table_name="${account_id}-terraform-state-lock"

    # Create S3 bucket if it doesn't exist
    if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        echo "Creating S3 bucket: $bucket_name"
        if [[ $region == "us-east-1" ]]; then
            aws s3api create-bucket \
                --bucket "$bucket_name" \
                --region "$region"
        else
            aws s3api create-bucket \
                --bucket "$bucket_name" \
                --region "$region" \
                --create-bucket-configuration LocationConstraint="$region"
        fi

        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled

        # Enable encryption
        aws s3api put-bucket-encryption \
            --bucket "$bucket_name" \
            --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }
                ]
            }'

        # Block public access
        aws s3api put-public-access-block \
            --bucket "$bucket_name" \
            --public-access-block-configuration \
                "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    else
        echo "S3 bucket already exists: $bucket_name"
    fi

    # Create DynamoDB table if it doesn't exist
    if ! aws dynamodb describe-table --table-name "$table_name" --region "$region" >/dev/null 2>&1; then
        echo "Creating DynamoDB table: $table_name"
        aws dynamodb create-table \
            --table-name "$table_name" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region "$region"

        aws dynamodb wait table-exists \
            --table-name "$table_name" \
            --region "$region"
    else
        echo "DynamoDB table already exists: $table_name"
    fi
    echo "Backend resources creation completed successfully!"

}

# Main execution
main() {
    local region="${1:-us-east-1}"
    
    echo "Checking AWS CLI and credentials..."
    check_aws_cli

    echo "Getting AWS Account ID..."
    account_id=$(aws sts get-caller-identity --query "Account" --output text)
    echo "Account ID: $account_id"
    echo "Creating backend resources..."
    create_backend_resources "$account_id" "$region"
}

# Execute main function
main "$@"
