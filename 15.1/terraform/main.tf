# Configure the AWS Provider

provider "aws" {
  profile = "jz_netology"
  region = "us-west-2"
}

resource "aws_vpc" "netology" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "netology_vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.netology.id
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.netology.id
  cidr_block              = "10.10.2.0/24"

  tags = {
    Name = "private"
  }
}

resource "aws_internet_gateway" "netology_gw" {
  vpc_id = aws_vpc.netology.id

  tags = {
    Name = "netology_gw"
  }
}

resource "aws_route" "netology_route_public" {
  route_table_id = aws_vpc.netology.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.netology_gw.id
}

resource "aws_route_table" "netology_route_private" {
  vpc_id = aws_vpc.netology.id

  tags = {
    Name = "netology_private_route"
  }
}

resource "aws_route_table_association" "netology_route_private" {
  subnet_id = aws_subnet.private.id
  route_table_id = aws_route_table.netology_route_private.id
}

resource "aws_security_group" "netology_sg" {
  name        = "netology_sg"
  description = "Allow SSH and ICMP inbound traffic"
  vpc_id      = aws_vpc.netology.id

  ingress {
    description      = "SSH to VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "ICMP to VPC"
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }


  tags = {
    Name = "netology_sg"
  }
}

resource "aws_eip" "netology_eip" {
  vpc = true
}

resource "aws_nat_gateway" "netology_nat_public" {
  allocation_id = aws_eip.netology_eip.id
  subnet_id     = aws_subnet.public.id
  depends_on = [aws_internet_gateway.netology_gw]

  tags = {
    Name = "netology_nat_public"
  }
}

resource "aws_route" "netology_route_private_nat" {
  route_table_id = aws_route_table.netology_route_private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.netology_nat_public.id
}

data "aws_ami" "ubuntu" {
  owners = ["099720109477"]
  most_recent      = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "test-server-public" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.netology_sg.id]
  key_name                    = "aws_jz"

  tags = {
    Name = "test-server-public"
  }
}

resource "aws_instance" "test-server-private" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.netology_sg.id]
  key_name                    = "aws_jz"

  tags = {
    Name = "test-server-private"
  }
}
