#!/bin/sh
set -e

# The inspiration from here: https://agateau.com/2014/template-for-shell-based-command-line-scripts/
#
# See also: https://natelandau.com/boilerplate-shell-script-template/
#           https://google.github.io/styleguide/shell.xml
#.          https://www.shellscript.sh/index.html


PROGNAME=$(basename $0)

die() {
    echo "$PROGNAME: $*" >&2
    exit 1
}

usage() {
    if [ "$*" != "" ] ; then
        echo "Error: $*"
    fi

    cat << EOF
Usage: $PROGNAME [OPTION ...] project
Check or create the bootstrap infrastructure

Options:
-h, --help             display this usage message and exit
-c, --check            check only, do not create
-p, --prefix           prefix, defaults to EIAC
-r, --region [REGION]  AWS region, defaults to current region - $AWS_DEFAULT_REGION
-d, --debug            set debug = true
EOF

    exit 1
}

prefix="eiac"
project="default"
region="${AWS_DEFAULT_REGION:-us-east-1}"
check=0
debug=0
while [ $# -gt 0 ] ; do
    case "$1" in
    -h|--help)
        usage
        ;;
    -c|--check)
        check=1
        ;;
    -d|--debug)
        debug=1
        ;;
    -p|--prefix)
        prefix="$2"
        shift
        ;;
    -r|--region)
        region="$2"
        shift
        ;;
    -*)
        usage "Unknown option '$1'"
        ;;
    *)
        if [ "$project" = "default" ] ; then
            project="$1"
        else
            usage "Too many arguments"
        fi
        ;;
    esac
    shift
done

# Run in debug mode, if set
if [ "${debug}" == "1" ]; then
  set -x
fi

ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
NAME="${prefix}-${ACCOUNT}-${region}"
S3_NAME="${NAME}-bootstrap"
DB_NAME="${NAME}"

cat <<EOF
#### Parameters

# - check=$check
# - prefix=$prefix
# - region=$region
# - S3_NAME="${S3_NAME}"
# - DB_NAME="${DB_NAME}"


EOF

# Steps
# Check if AWS bucket exist

#BIN_DIR=$(dirname ${BASH_SOURCE[0]})
#source $BIN_DIR/aws_common_functions.sh
export AWS_DEFAULT_REGION=$region

bucket_exists()
{
    BUCKET_NAME=$1
    if [[ $(aws s3api list-buckets --query 'Buckets[?Name == `'$BUCKET_NAME'`].[Name]' --output text) = $BUCKET_NAME ]]; then 
        echo "# Bucket $BUCKET_NAME exists"; 
    else 
        echo "# Bucket $BUCKET_NAME does not exist"
        if [ $check == 0 ]; then
            echo "# Creating $BUCKET_NAME"
            aws s3 mb s3://$BUCKET_NAME
            aws s3api put-bucket-encryption \
                --bucket $BUCKET_NAME \
                --server-side-encryption-configuration={\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}
            aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled                
        else
            echo "# NOT creating - switched off by the check=$check"
        fi
    fi
}

table_exists()
{
    if [[ -z $(aws dynamodb describe-table --table-name $1 2>&1 | grep error)  ]]
    then 
            echo "# Table $1 exists"
#            return 0
    else 
            echo "# Table $1 does not exist, please run the TF script in bootstrap.tf"
cat <<EOF | tee bootstrap.tf

provider "aws" {
  version = "~> 2.0"
  region  = "$region" 
}

# create-dynamodb-lock-table.tf
resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
  name           = "$NAME"
  hash_key       = "LockID"
  read_capacity  = 5
  write_capacity = 5
  attribute {
        name = "LockID"
        type = "S"
  }
  tags = {
        Name = "DynamoDB Terraform State Lock Table"
  }
}

EOF

    fi
}


#echo "Account and Region:"
#aws configure list
#aws sts get-caller-identity

echo "# Testing bucket existence $S3_NAME:"
echo "#"
bucket_exists $S3_NAME

echo "# Testing table existence $NAME:"
echo "#"
table_exists $NAME

echo
echo " # .. the file ${project}.tfbackend:"
cat <<EOF | tee ${project}.tfbackend 
bucket  = "$BUCKET_NAME"
key     = "${project}-terraform.tfstate" 
EOF


cat <<EOF


# Copy the file ${project}.tfbackend to your project and change the backend.tf definition to include it
# then run

cd ../YOURPROJECT
terraform init
terraform workspace new $NAME
terraform plan  
terraform apply 
EOF
