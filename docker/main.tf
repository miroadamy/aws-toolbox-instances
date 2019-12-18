resource "aws_key_pair" "my_key" {
  key_name   = "miro-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA2TGlNFMPpCcPrrmQiotr0M5fyYGgEQxug7QMBwQLaOR+XEa6KIGTljfzTQrknlqTi1pDP0HNnIAoJyRkanGkJ6eqga2TmlStJkC/ooQoWBqB1T7RoLJFGHs0Khu9YoQN8ncxTd64z201eh1abzTGOzdMhsYJyoSTmOPQEGQlUq7GLFZ7cuZ4oROElF9L9ahQJbmgvmPBJMJvoI+ajY0c5EedzWyvtsPJlQMb5ZxPdRj81iEmtduVfvJU7vqeDDU/2Kme2LwEXmVSfi8VyG5dsfvKmqPplw3xbzGXMKu3b1PiSVAN7U7tBv41+IqDjfX76QLGnbeaVd9jajwIsLnJjw== miro@Radegast.local"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "examplesg" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }  
}

resource "aws_instance" "ec2_instance" {
  ami             = data.aws_ami.amazon-linux.id
  instance_type   = "t2.small"
  vpc_security_group_ids = [aws_security_group.examplesg.id]
  key_name        = aws_key_pair.my_key.id

  root_block_device {
    volume_size           = "100"
    volume_type           = "gp2"
  }  

  user_data_base64 = base64encode(local.user_data)

  tags = {
    Name = "first-ec2-instance"
  }
}