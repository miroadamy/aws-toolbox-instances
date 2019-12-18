locals {
  user_data = <<EOF
#!/bin/bash
sudo yum update -d
sudo yum install -y docker
sudo systemctl enable docker
sudo service docker start
sudo usermod -a -G docker ec2-user 
EOF
}