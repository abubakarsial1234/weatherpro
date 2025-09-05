terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # --- FINAL SOLUTION: REMOTE BACKEND CONFIGURATION ---
  # Yeh Terraform ko batata hai ke apni "yaad-dasht" kahan save karni hai
  backend "s3" {
    # Yahan apna UNIQUE S3 bucket naam likhein jo aapne banaya tha
    bucket         = "abubakarsial-weather-app-tfstate" 
    key            = "weather-app/terraform.tfstate"
    region         = "us-east-1"
    
    # Yeh state file ko lock karne ke liye hai
    dynamodb_table = "terraform-state-locks" 
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- VPC and Networking ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "main-vpc" }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-2" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "public-route-table" }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# --- Security Groups ---
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "alb-sg" }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-instance-sg"
  description = "Allow traffic from ALB and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

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
  tags = { Name = "ec2-sg" }
}

# --- Application Load Balancer ---
resource "aws_lb" "main" {
  name               = "weather-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  tags               = { Name = "weather-app-alb" }
}

resource "aws_lb_target_group" "frontend" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group" "backend" {
  name     = "backend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/api/weather"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# --- EC2 Instances ---
data "template_file" "frontend_user_data" {
  template = file("${path.module}/user-data.sh.tpl")
  vars = {
    proxy_port = "5000"
  }
}

data "template_file" "backend_user_data" {
  template = file("${path.module}/user-data.sh.tpl")
  vars = {
    proxy_port = "5001"
  }
}

variable "key_name" {
  description = "Name of the EC2 Key Pair to use"
  default     = "pairkey"
}

resource "aws_instance" "frontend" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t3.small"
  subnet_id     = aws_subnet.public_1.id
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data = data.template_file.frontend_user_data.rendered
  tags = { Name = "frontend-instance" }
}

resource "aws_instance" "backend" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t3.small"
  subnet_id     = aws_subnet.public_2.id
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data = data.template_file.backend_user_data.rendered
  tags = { Name = "backend-instance" }
}

resource "aws_lb_target_group_attachment" "frontend" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "backend" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend.id
  port             = 80
}

# --- Outputs ---
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "frontend_instance_public_ip" {
  description = "The Public IP of the Frontend instance"
  value       = aws_instance.frontend.public_ip
}

output "backend_instance_public_ip" {
  description = "The Public IP of the Backend instance"
  value       = aws_instance.backend.public_ip
}
