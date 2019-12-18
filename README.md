# aws-toolbox-instances - Creating AWS Tool Instances

Objective
===========

I do not want to keep working with local OS-X Docker instance for larger tasks - e.g. building Hybris containers. The machine is slow, pushing/pulling multi-GB images to cloud depends on internet connectity speed and Docker keeps running out of memory.

Instead, I want

* programatically spin an EC2 instance with enough RAM and Disk space
* create all infra necessary using TF
* install Docker
* SSH to the machine
* do the work there
* shut down the instance


Using S3 for state
-------------------

I will use S3 + Dynamo DB for state storage.

The S3 bucket + DynamoDB database will be created by bootstrap script that will:

* define the S3 name and DBtable name, using naming scheme: ``$PREFIX-${AWS_ACCOUNT}-${AWS_REGION}-bootstrap``
* within the S3 bucket, the main folder is ${ENVIRONMENT_NAME}


The Bootstrap parameters are:

* PREFIX - any string, I will use EIAC => Everything Is A Code
* ACCOUNT_NUMBER_OR_PREFIX (<= get from credentials)
* REGION (<= $AWS_DEFAULT_REGION)
* AWS credentials in environment in form or AWS_PROFILE or Key+SecretKey+Token

Whether or not I have the bootstrap ready is whether or not:

* the S3 bucket exists
* the DynamoDB exists


Pre-requisites
---------------

* AWS CLI
* Credentials


Bootstrapping
=============

The process of bootstrapping is preparing a region in AWS for consequent deployments of tool instances.

Bootstrap is creation of remote state storage for Terraform, which consists of S3 bucket DynamoDB locking table.

We will create the bucket using AWS CLI and bash script and use terraform to create the DB table.

The script is here: src/bootstrap/bootstrap.sh


How it works
------------

Script retrieves the ACCOUNT id and region and constructs the name for bucket and table

    ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
    NAME="${prefix}-${ACCOUNT}-${region}"
    S3_NAME="${NAME}-bootstrap"
    DB_NAME="${NAME}"

If bucket exists, it only reports it, otherwise creates it with proper options:

* versioning
* encryption

Running the script:


    $ ./bootstrap.sh  -r us-east-1 docker
    #### Parameters

    # - check=0
    # - prefix=eiac
    # - region=us-east-1
    # - S3_NAME="eiac-144153993531-us-east-1-bootstrap"
    # - DB_NAME="eiac-144153993531-us-east-1"


    # Testing bucket existence eiac-144153993531-us-east-1-bootstrap:
    #
    # Bucket eiac-144153993531-us-east-1-bootstrap exists
    # Testing table existence eiac-144153993531-us-east-1:
    #
    # Table eiac-144153993531-us-east-1 exists

    # .. the file docker.tfbackend:
    bucket  = "eiac-144153993531-us-east-1-bootstrap"
    key     = "docker-terraform.tfstate"


    # Copy the file docker.tfbackend to your project and change the backend.tf definition to include it
    # then run

    cd ../YOURPROJECT
    terraform init
    terraform workspace new eiac-144153993531-us-east-1
    terraform plan
    terraform apply


After that, it writes out a file ``PROJECT.tfbackend`` that is supposed to be a backend config for Terraform scripts used elsewhere. The file defines the backend with the just created S3 bucket. The PROJECT is the value passed to bootstrap script. If no argument is passed, ``default.tfbackend`` is generated - see src/bootstrap/default.tfbackend

The config points to S3 bucket and sets the key so that multiple projects can store state in the bucket.


If the dynamo table does not exist, the second file the script generates is the ``bootstrap.tf`` - a terraform script that creates second part of backend: the Dynamo DB table -  see src/bootstrap/bootstrap.tf

After the script finishes, run in the script directory the commands that script suggested, e.g.

    terraform init
    terraform workspage eiac-144153993531-us-east-1
    terraform plan
    terraform apply

which completes the bootstrapping. The region you use is now prepared for the tool creation.

Note that the bootstrap is using LOCAL STATE. This is by design.

For separation of the accounts and regions, we use workspaces:

.. code::

    $ terraform workspace list
      default
    * eiac-144153993531-us-east-1


Docker workstation
===================

The source code for this is in ``src/docker``. It assumes that AWS region has bootstrap installed

Backend initialization
----------------------

We need to use the generated backend config in ``terraform init``


.. code::

    $ terraform init -backend-config=docker.tfbackend

    Initializing the backend...

    Initializing provider plugins...

    Terraform has been successfully initialized!

    You may now begin working with Terraform. Try running "terraform plan" to see
    any changes that are required for your infrastructure. All Terraform commands
    should now work.

    If you ever set or change modules or backend configuration for Terraform,
    rerun this command to reinitialize your working directory. If you forget, other
    commands will detect it and remind you to do so if necessary.


Environment creation
--------------------

After this, we can do ``plan`` and ``apply``

.. code::

    $ terraform plan
    Acquiring state lock. This may take a few moments...
    Refreshing Terraform state in-memory prior to plan...
    The refreshed state will be used to calculate this plan, but will not be
    persisted to local or remote state storage.

    data.aws_vpc.default: Refreshing state...
    data.aws_ami.amazon_linux: Refreshing state...
    data.aws_ami.latest-ubuntu: Refreshing state...
    data.aws_ami.amazon-linux-2: Refreshing state...
    data.aws_ami.latest_ecs: Refreshing state...
    data.aws_subnet_ids.all: Refreshing state...

    ------------------------------------------------------------------------

    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
      + create

    Terraform will perform the following actions:

      # aws_instance.ec2_instance will be created
      + resource "aws_instance" "ec2_instance" {
          + ami                          = "ami-00eb20669e0990cb4"
          + arn                          = (known after apply)
          + associate_public_ip_address  = (known after apply)
          + availability_zone            = (known after apply)
          + cpu_core_count               = (known after apply)
          + cpu_threads_per_core         = (known after apply)
          + get_password_data            = false
          + host_id                      = (known after apply)
          + id                           = (known after apply)
          + instance_state               = (known after apply)
          + instance_type                = "t2.micro"
          + ipv6_address_count           = (known after apply)
          + ipv6_addresses               = (known after apply)
          + key_name                     = (known after apply)
          + network_interface_id         = (known after apply)
          + password_data                = (known after apply)
          + placement_group              = (known after apply)
          + primary_network_interface_id = (known after apply)
          + private_dns                  = (known after apply)
          + private_ip                   = (known after apply)
          + public_dns                   = (known after apply)
          + public_ip                    = (known after apply)
          + security_groups              = (known after apply)
          + source_dest_check            = true
          + subnet_id                    = (known after apply)
          + tags                         = {
              + "Name" = "first-ec2-instance"
            }
          + tenancy                      = (known after apply)
          + user_data_base64             = "IyEvYmluL2Jhc2gKZWNobyAiSGVsbG8gVGVycmFmb3JtISIK"
          + volume_tags                  = (known after apply)
          + vpc_security_group_ids       = (known after apply)

          + ebs_block_device {
              + delete_on_termination = (known after apply)
              + device_name           = (known after apply)
              + encrypted             = (known after apply)
              + iops                  = (known after apply)
              + kms_key_id            = (known after apply)
              + snapshot_id           = (known after apply)
              + volume_id             = (known after apply)
              + volume_size           = (known after apply)
              + volume_type           = (known after apply)
            }

          + ephemeral_block_device {
              + device_name  = (known after apply)
              + no_device    = (known after apply)
              + virtual_name = (known after apply)
            }

          + network_interface {
              + delete_on_termination = (known after apply)
              + device_index          = (known after apply)
              + network_interface_id  = (known after apply)
            }

          + root_block_device {
              + delete_on_termination = true
              + encrypted             = (known after apply)
              + iops                  = (known after apply)
              + kms_key_id            = (known after apply)
              + volume_id             = (known after apply)
              + volume_size           = 100
              + volume_type           = "gp2"
            }
        }

      # aws_key_pair.my_key will be created
      + resource "aws_key_pair" "my_key" {
          + fingerprint = (known after apply)
          + id          = (known after apply)
          + key_name    = "miro-key"
          + public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA2TGlNFMPpCcPrrmQiotr0M5fyYGgEQxug7QMBwQLaOR+XEa6KIGTljfzTQrknlqTi1pDP0HNnIAoJyRkanGkJ6eqga2TmlStJkC/ooQoWBqB1T7RoLJFGHs0Khu9YoQN8ncxTd64z201eh1abzTGOzdMhsYJyoSTmOPQEGQlUq7GLFZ7cuZ4oROElF9L9ahQJbmgvmPBJMJvoI+ajY0c5EedzWyvtsPJlQMb5ZxPdRj81iEmtduVfvJU7vqeDDU/2Kme2LwEXmVSfi8VyG5dsfvKmqPplw3xbzGXMKu3b1PiSVAN7U7tBv41+IqDjfX76QLGnbeaVd9jajwIsLnJjw== miro@Radegast.local"
        }

      # aws_security_group.examplesg will be created
      + resource "aws_security_group" "examplesg" {
          + arn                    = (known after apply)
          + description            = "Managed by Terraform"
          + egress                 = (known after apply)
          + id                     = (known after apply)
          + ingress                = [
              + {
                  + cidr_blocks      = [
                      + "0.0.0.0/0",
                    ]
                  + description      = ""
                  + from_port        = 22
                  + ipv6_cidr_blocks = []
                  + prefix_list_ids  = []
                  + protocol         = "tcp"
                  + security_groups  = []
                  + self             = false
                  + to_port          = 22
                },
            ]
          + name                   = (known after apply)
          + owner_id               = (known after apply)
          + revoke_rules_on_delete = false
          + vpc_id                 = (known after apply)
        }

    Plan: 3 to add, 0 to change, 0 to destroy.

    ------------------------------------------------------------------------

    Note: You didn't specify an "-out" parameter to save this plan, so Terraform
    can't guarantee that exactly these actions will be performed if
    "terraform apply" is subsequently run.

    Releasing state lock. This may take a few moments...

Apply

.. code::

    $ terraform apply
    Acquiring state lock. This may take a few moments...
    data.aws_vpc.default: Refreshing state...
    data.aws_ami.amazon_linux: Refreshing state...
    data.aws_ami.amazon-linux-2: Refreshing state...
    data.aws_ami.latest-ubuntu: Refreshing state...
    data.aws_ami.latest_ecs: Refreshing state...
    data.aws_subnet_ids.all: Refreshing state...

    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
      + create

    Terraform will perform the following actions:

      # aws_instance.ec2_instance will be created
      + resource "aws_instance" "ec2_instance" {
          + ami                          = "ami-00eb20669e0990cb4"
          + arn                          = (known after apply)
          + associate_public_ip_address  = (known after apply)
          + availability_zone            = (known after apply)
          + cpu_core_count               = (known after apply)
          + cpu_threads_per_core         = (known after apply)
          + get_password_data            = false
          + host_id                      = (known after apply)
          + id                           = (known after apply)
          + instance_state               = (known after apply)
          + instance_type                = "t2.micro"
          + ipv6_address_count           = (known after apply)
          + ipv6_addresses               = (known after apply)
          + key_name                     = (known after apply)
          + network_interface_id         = (known after apply)
          + password_data                = (known after apply)
          + placement_group              = (known after apply)
          + primary_network_interface_id = (known after apply)
          + private_dns                  = (known after apply)
          + private_ip                   = (known after apply)
          + public_dns                   = (known after apply)
          + public_ip                    = (known after apply)
          + security_groups              = (known after apply)
          + source_dest_check            = true
          + subnet_id                    = (known after apply)
          + tags                         = {
              + "Name" = "first-ec2-instance"
            }
          + tenancy                      = (known after apply)
          + user_data_base64             = "IyEvYmluL2Jhc2gKZWNobyAiSGVsbG8gVGVycmFmb3JtISIK"
          + volume_tags                  = (known after apply)
          + vpc_security_group_ids       = (known after apply)

          + ebs_block_device {
              + delete_on_termination = (known after apply)
              + device_name           = (known after apply)
              + encrypted             = (known after apply)
              + iops                  = (known after apply)
              + kms_key_id            = (known after apply)
              + snapshot_id           = (known after apply)
              + volume_id             = (known after apply)
              + volume_size           = (known after apply)
              + volume_type           = (known after apply)
            }

          + ephemeral_block_device {
              + device_name  = (known after apply)
              + no_device    = (known after apply)
              + virtual_name = (known after apply)
            }

          + network_interface {
              + delete_on_termination = (known after apply)
              + device_index          = (known after apply)
              + network_interface_id  = (known after apply)
            }

          + root_block_device {
              + delete_on_termination = true
              + encrypted             = (known after apply)
              + iops                  = (known after apply)
              + kms_key_id            = (known after apply)
              + volume_id             = (known after apply)
              + volume_size           = 100
              + volume_type           = "gp2"
            }
        }

      # aws_key_pair.my_key will be created
      + resource "aws_key_pair" "my_key" {
          + fingerprint = (known after apply)
          + id          = (known after apply)
          + key_name    = "miro-key"
          + public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA2TGlNFMPpCcPrrmQiotr0M5fyYGgEQxug7QMBwQLaOR+XEa6KIGTljfzTQrknlqTi1pDP0HNnIAoJyRkanGkJ6eqga2TmlStJkC/ooQoWBqB1T7RoLJFGHs0Khu9YoQN8ncxTd64z201eh1abzTGOzdMhsYJyoSTmOPQEGQlUq7GLFZ7cuZ4oROElF9L9ahQJbmgvmPBJMJvoI+ajY0c5EedzWyvtsPJlQMb5ZxPdRj81iEmtduVfvJU7vqeDDU/2Kme2LwEXmVSfi8VyG5dsfvKmqPplw3xbzGXMKu3b1PiSVAN7U7tBv41+IqDjfX76QLGnbeaVd9jajwIsLnJjw== miro@Radegast.local"
        }

      # aws_security_group.examplesg will be created
      + resource "aws_security_group" "examplesg" {
          + arn                    = (known after apply)
          + description            = "Managed by Terraform"
          + egress                 = (known after apply)
          + id                     = (known after apply)
          + ingress                = [
              + {
                  + cidr_blocks      = [
                      + "0.0.0.0/0",
                    ]
                  + description      = ""
                  + from_port        = 22
                  + ipv6_cidr_blocks = []
                  + prefix_list_ids  = []
                  + protocol         = "tcp"
                  + security_groups  = []
                  + self             = false
                  + to_port          = 22
                },
            ]
          + name                   = (known after apply)
          + owner_id               = (known after apply)
          + revoke_rules_on_delete = false
          + vpc_id                 = (known after apply)
        }

    Plan: 3 to add, 0 to change, 0 to destroy.

    Do you want to perform these actions?
      Terraform will perform the actions described above.
      Only 'yes' will be accepted to approve.

      Enter a value: yes

    aws_key_pair.my_key: Creating...
    aws_security_group.examplesg: Creating...
    aws_key_pair.my_key: Creation complete after 1s [id=miro-key]
    aws_security_group.examplesg: Creation complete after 5s [id=sg-01db6ce5308df7eba]
    aws_instance.ec2_instance: Creating...
    aws_instance.ec2_instance: Still creating... [10s elapsed]
    aws_instance.ec2_instance: Still creating... [20s elapsed]
    aws_instance.ec2_instance: Still creating... [30s elapsed]
    aws_instance.ec2_instance: Still creating... [40s elapsed]
    aws_instance.ec2_instance: Creation complete after 46s [id=i-0de91d60b9af78d13]

    Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
    Releasing state lock. This may take a few moments...

The instance is now available to log in. It has 100 GB disk and is of Amazon Linux (RHEL type)


    $ awless list instances
    |        ID ▲         |    ZONE    |        NAME        |  STATE  |   TYPE   |  PUBLIC IP  |  PRIVATE IP   | UPTIME  | KEYPAIR  |
    |---------------------|------------|--------------------|---------|----------|-------------|---------------|---------|----------|
    | i-0de91d60b9af78d13 | us-east-1c | first-ec2-instance | running | t2.micro | 3.89.63.207 | 172.31.22.213 | 92 secs | miro-key |

    ➜  docker git:(master) ✗ ssh ec2-user@3.89.63.207
    The authenticity of host '3.89.63.207 (3.89.63.207)' can't be established.
    ECDSA key fingerprint is SHA256:HbFYWRDGl+mo5qIwiZyxAMH8AxmrjSCkCRz8lfWFIR4.
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added '3.89.63.207' (ECDSA) to the list of known hosts.

           __|  __|_  )
           _|  (     /   Amazon Linux AMI
          ___|\___|___|

    https://aws.amazon.com/amazon-linux-ami/2018.03-release-notes/

    [ec2-user@ip-172-31-22-213 ~]$ df -h
    Filesystem      Size  Used Avail Use% Mounted on
    devtmpfs        483M   60K  483M   1% /dev
    tmpfs           493M     0  493M   0% /dev/shm
    /dev/xvda1       99G  1.1G   98G   2% /

    [ec2-user@ip-172-31-22-213 ~]$ cat /etc/os-release
    NAME="Amazon Linux AMI"
    VERSION="2018.03"
    ID="amzn"
    ID_LIKE="rhel fedora"
    VERSION_ID="2018.03"
    PRETTY_NAME="Amazon Linux AMI 2018.03"
    ANSI_COLOR="0;33"
    CPE_NAME="cpe:/o:amazon:linux:2018.03:ga"
    HOME_URL="http://aws.amazon.com/amazon-linux-ami/"

Docker is installed as part of the userdata:


    [ec2-user@ip-172-31-47-243 ~]$ docker --version
    Docker version 18.09.9-ce, build 039a7df
    
    [ec2-user@ip-172-31-47-243 ~]$ docker ps
    CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
    
    [ec2-user@ip-172-31-47-243 ~]$ logout


Cleanup
-------


    $ terraform destroy
    Acquiring state lock. This may take a few moments...
    data.aws_ami.latest-ubuntu: Refreshing state...
    data.aws_vpc.default: Refreshing state...
    aws_key_pair.my_key: Refreshing state... [id=miro-key]
    data.aws_ami.amazon-linux-2: Refreshing state...
    data.aws_ami.amazon_linux: Refreshing state...
    data.aws_ami.latest_ecs: Refreshing state...
    aws_security_group.examplesg: Refreshing state... [id=sg-01db6ce5308df7eba]
    aws_instance.ec2_instance: Refreshing state... [id=i-0de91d60b9af78d13]
    data.aws_subnet_ids.all: Refreshing state...

    An execution plan has been generated and is shown below.
    Resource actions are indicated with the following symbols:
      - destroy

    Terraform will perform the following actions:

      # aws_instance.ec2_instance will be destroyed
      - resource "aws_instance" "ec2_instance" {
          - ami                          = "ami-00eb20669e0990cb4" -> null
          - arn                          = "arn:aws:ec2:us-east-1:144153993531:instance/i-0de91d60b9af78d13" -> null
          - associate_public_ip_address  = true -> null
          - availability_zone            = "us-east-1c" -> null
          - cpu_core_count               = 1 -> null
          - cpu_threads_per_core         = 1 -> null
          - disable_api_termination      = false -> null
          - ebs_optimized                = false -> null
          - get_password_data            = false -> null
          - id                           = "i-0de91d60b9af78d13" -> null
          - instance_state               = "running" -> null
          - instance_type                = "t2.micro" -> null
          - ipv6_address_count           = 0 -> null
          - ipv6_addresses               = [] -> null
          - key_name                     = "miro-key" -> null
          - monitoring                   = false -> null
          - primary_network_interface_id = "eni-048d7c31bb0ec192e" -> null
          - private_dns                  = "ip-172-31-22-213.ec2.internal" -> null
          - private_ip                   = "172.31.22.213" -> null
          - public_dns                   = "ec2-3-89-63-207.compute-1.amazonaws.com" -> null
          - public_ip                    = "3.89.63.207" -> null
          - security_groups              = [
              - "terraform-20191218124244964000000001",
            ] -> null
          - source_dest_check            = true -> null
          - subnet_id                    = "subnet-158be85e" -> null
          - tags                         = {
              - "Name" = "first-ec2-instance"
            } -> null
          - tenancy                      = "default" -> null
          - user_data_base64             = "IyEvYmluL2Jhc2gKZWNobyAiSGVsbG8gVGVycmFmb3JtISIK" -> null
          - volume_tags                  = {} -> null
          - vpc_security_group_ids       = [
              - "sg-01db6ce5308df7eba",
            ] -> null

          - credit_specification {
              - cpu_credits = "standard" -> null
            }

          - root_block_device {
              - delete_on_termination = true -> null
              - encrypted             = false -> null
              - iops                  = 300 -> null
              - volume_id             = "vol-07592d19482a49105" -> null
              - volume_size           = 100 -> null
              - volume_type           = "gp2" -> null
            }
        }

      # aws_key_pair.my_key will be destroyed
      - resource "aws_key_pair" "my_key" {
          - fingerprint = "60:34:83:06:ca:30:25:05:e4:93:ab:23:b8:3e:12:17" -> null
          - id          = "miro-key" -> null
          - key_name    = "miro-key" -> null
          - public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA2TGlNFMPpCcPrrmQiotr0M5fyYGgEQxug7QMBwQLaOR+XEa6KIGTljfzTQrknlqTi1pDP0HNnIAoJyRkanGkJ6eqga2TmlStJkC/ooQoWBqB1T7RoLJFGHs0Khu9YoQN8ncxTd64z201eh1abzTGOzdMhsYJyoSTmOPQEGQlUq7GLFZ7cuZ4oROElF9L9ahQJbmgvmPBJMJvoI+ajY0c5EedzWyvtsPJlQMb5ZxPdRj81iEmtduVfvJU7vqeDDU/2Kme2LwEXmVSfi8VyG5dsfvKmqPplw3xbzGXMKu3b1PiSVAN7U7tBv41+IqDjfX76QLGnbeaVd9jajwIsLnJjw== miro@Radegast.local" -> null
        }

      # aws_security_group.examplesg will be destroyed
      - resource "aws_security_group" "examplesg" {
          - arn                    = "arn:aws:ec2:us-east-1:144153993531:security-group/sg-01db6ce5308df7eba" -> null
          - description            = "Managed by Terraform" -> null
          - egress                 = [] -> null
          - id                     = "sg-01db6ce5308df7eba" -> null
          - ingress                = [
              - {
                  - cidr_blocks      = [
                      - "0.0.0.0/0",
                    ]
                  - description      = ""
                  - from_port        = 22
                  - ipv6_cidr_blocks = []
                  - prefix_list_ids  = []
                  - protocol         = "tcp"
                  - security_groups  = []
                  - self             = false
                  - to_port          = 22
                },
            ] -> null
          - name                   = "terraform-20191218124244964000000001" -> null
          - owner_id               = "144153993531" -> null
          - revoke_rules_on_delete = false -> null
          - tags                   = {} -> null
          - vpc_id                 = "vpc-ee7a1296" -> null
        }

    Plan: 0 to add, 0 to change, 3 to destroy.

    Do you really want to destroy all resources?
      Terraform will destroy all your managed infrastructure, as shown above.
      There is no undo. Only 'yes' will be accepted to confirm.

      Enter a value: yes

    aws_instance.ec2_instance: Destroying... [id=i-0de91d60b9af78d13]
    aws_instance.ec2_instance: Still destroying... [id=i-0de91d60b9af78d13, 10s elapsed]
    aws_instance.ec2_instance: Still destroying... [id=i-0de91d60b9af78d13, 20s elapsed]
    aws_instance.ec2_instance: Still destroying... [id=i-0de91d60b9af78d13, 30s elapsed]
    aws_instance.ec2_instance: Destruction complete after 37s
    aws_key_pair.my_key: Destroying... [id=miro-key]
    aws_security_group.examplesg: Destroying... [id=sg-01db6ce5308df7eba]
    aws_key_pair.my_key: Destruction complete after 1s
    aws_security_group.examplesg: Destruction complete after 2s

    Destroy complete! Resources: 3 destroyed.
    Releasing state lock. This may take a few moments...
