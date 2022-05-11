# Configure the AWS Provider

provider "aws" {
  profile = "jz_netology"
  region = "us-west-2"
}

# Create network resources

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
  availability_zone       = "us-west-2c"

  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "public_lb" {
  vpc_id                  = aws_vpc.netology.id
  cidr_block              = "10.10.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2d"

  tags = {
    Name = "public_lb"
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

  ingress {
    description      = "HTTP to VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
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

# Create AWS EC2 for tests

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

resource "aws_launch_configuration" "web-server-config" {
  name                        = "web-server-config"
  image_id                    = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  security_groups             = [aws_security_group.netology_sg.id]
  key_name                    = "aws_jz"
  user_data                   = <<-EOF
                                   #!/bin/bash
                                   S3URL="https://${aws_s3_bucket.netology-s3.bucket_regional_domain_name}/${aws_s3_object.netology-jpg.key}"
                                   sudo apt-get update
                                   sudo apt-get -y install nginx
                                   service nginx start
                                   echo "<html><body><p>NETOLOGY S3</p><img src='$S3URL'>" > /var/www/html/index.html
                                EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web-server-ag" {
  name                 = "web-server-ag"
  launch_configuration = aws_launch_configuration.web-server-config.name
  desired_capacity     = 3
  min_size             = 3
  max_size             = 3
  vpc_zone_identifier  = [aws_subnet.public.id]

  lifecycle {
    create_before_destroy = true
  }
}

# Create Load Balancer

resource "aws_lb" "netology-server-lb" {
  name               = "netology-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.netology_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_lb.id]
}

resource "aws_lb_target_group" "netology-lb-tg" {
  name                          = "netology-lb-tg"
  port                          = 80
  protocol                      = "HTTP"
  vpc_id                        = aws_vpc.netology.id
  load_balancing_algorithm_type = "round_robin"
  target_type                   = "instance"

}

resource "aws_lb_listener" "netology-lb-listener" {
  load_balancer_arn = aws_lb.netology-server-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.netology-lb-tg.arn
  }
}

resource "aws_autoscaling_attachment" "netology-as-att" {
  autoscaling_group_name = aws_autoscaling_group.web-server-ag.id
  lb_target_group_arn   = aws_lb_target_group.netology-lb-tg.arn
}


# Create S3 bucket

resource "aws_s3_bucket" "netology-s3" {
  bucket = "netology-s3-bucket"

  tags = {
    Name        = "netology-s3"
  }
}

resource "aws_s3_bucket_acl" "netology-s3-acl" {
  bucket = aws_s3_bucket.netology-s3.id
  acl = "public-read"
}

resource "aws_s3_object" "netology-jpg" {
  bucket = aws_s3_bucket.netology-s3.bucket
  key = "netology.jpg"
  content_type = "image/jpeg"
  source = "./images/netology.jpg"
  acl = "public-read"
}
