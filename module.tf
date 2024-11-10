# Variables
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "key_name" {}
variable "region" {
  default = "eu-central-1"
}

# Provider
provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Data: Get latest Ubuntu AMI
data "aws_ami" "aws_ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID for Ubuntu AMIs

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Default VPC
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16" # Define the VPC's CIDR block

  tags = {
    Name  = "ExampleVPC"
    Owner = "DevOps Team"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"

  tags = {
    Name = "public-subnet"
  }
}

# Public Subnet in a different Availability Zone
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1b" # Use a different AZ

  tags = {
    Name = "public-subnet-2"
  }
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "eu-central-1a"

  tags = {
    Name = "private-subnet"
  }
}

# Internet Gateway for Public Subnet
resource "aws_internet_gateway" "example_gw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "ExampleGateway"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example_gw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  #  vpc = true
}

# NAT Gateway for Private Subnet
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "nat-gateway"
  }
}

# Route Table for Private Subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "private-route-table"
  }
}

# Associate Private Subnet with Private Route Table
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lb-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets = [
    aws_subnet.public_subnet.id,
    aws_subnet.public_subnet_2.id # Include the second subnet
  ]

  tags = {
    Name = "app-lb"
  }
}


# Target Group for Private EC2 Instance
resource "aws_lb_target_group" "app_tg" {
  name        = "app-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.default.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Listener for Load Balancer
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Security Group for Private EC2 Instance
resource "aws_security_group" "private_instance_sg" {
  vpc_id = aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-instance-sg"
  }
}

# EC2 Instance in Private Subnet
resource "aws_instance" "aws_ubuntu" {
  instance_type = "t2.micro"
  ami           = data.aws_ami.aws_ubuntu.id
  #key_name                    = var.key_name
  user_data                   = file("userdata.tpl")
  security_groups             = [aws_security_group.private_instance_sg.id]
  associate_public_ip_address = false
  subnet_id                   = aws_subnet.private_subnet.id

  tags = {
    Name = "nginx-private-instance"
  }
}

# Attach EC2 Instance to Target Group
resource "aws_lb_target_group_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.aws_ubuntu.id
  port             = 80
}

# Outputs
output "load_balancer_dns" {
  value = aws_lb.app_lb.dns_name
}
