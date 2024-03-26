provider "aws" {
  region = "us-east-1" 
}

variable "app_server_regions" {
  default = ["us-east-1", "us-west-2"] 
}

data "aws_region" "selected" {
  for_each = toset(var.app_server_regions)
  name     = each.value
}

data "aws_availability_zones" "available" {
  for_each = data.aws_region.selected

  filter {
    name   = "region-name"
    values = [each.value.name]
  }
}

data "aws_subnet" "available" {
  vpc_id = "vpc-bbf647c3"
  filter {
    name   = "cidr-block"
    values = ["172.31.0.0/20"]
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app_sg"
  description = "Allow inbound traffic to the app servers"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name        = "db_sg"
  description = "Allow inbound traffic to the database server"
  
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_server" {
  count                  = length(var.app_server_regions)
  ami                    = "ami-0c55b159cbfafe1f0" # Ubuntu 20.04 LTS AMI
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  user_data              = file("userdata.sh")
  security_groups        = [aws_security_group.app_sg.id] 
  tags = {
    Name = "app_server-${var.app_server_regions[count.index]}"
  }
}


resource "aws_instance" "db_server" {
  ami                    = "ami-0c55b159cbfafe1f0" # Ubuntu 20.04 LTS AMI
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a" 
  user_data              = file("userdata.sh")
  security_groups        = [aws_security_group.db_sg.id] 
  tags = {
    Name = "db_server"
  }
}

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  
  security_groups = [aws_security_group.app_sg.id]

  subnets = [data.aws_subnet.available.id]

  enable_deletion_protection = false

  tags = {
    Name = "app_lb"
  }
}


resource "aws_lb_target_group" "app_target_group" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"

  target_type = "instance"

  vpc_id = "vpc-12345678"

  depends_on = [
    aws_lb.app_lb,
  ]
}

resource "aws_lb_target_group_attachment" "app_target_group_attachment" {
  count             = length(var.app_server_regions)
  target_group_arn  = aws_lb_target_group.app_target_group.arn
  target_id         = aws_instance.app_server[count.index].id
  port              = 80
}

output "load_balancer_url" {
  value = aws_lb.app_lb.dns_name
}