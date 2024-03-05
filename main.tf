resource "aws_vpc" "my-vpc" {
  cidr_block       = "12.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my-vpc"
  }
}

resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "my-igw"
  }
}

#resource "aws_internet_gateway_attachment" "my-igw" {



resource "aws_subnet" "my-subnet1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "12.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

}

resource "aws_subnet" "my-subnet2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "12.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

}

resource "aws_route_table" "my-rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-igw.id
  }

  tags = {
    Name = "my-rt"
  }
}

resource "aws_route_table_association" "my-rt1" {
  subnet_id      = aws_subnet.my-subnet1.id
  route_table_id = aws_route_table.my-rt.id

}

resource "aws_route_table_association" "my-rt2" {
  subnet_id      = aws_subnet.my-subnet2.id
  route_table_id = aws_route_table.my-rt.id

}

resource "aws_security_group" "my-web-Sg" {
  name   = "web"
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
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

  tags = {
    Name = "my-Web-sg"
  }
}

resource "aws_s3_bucket" "my-s3-bucket" {
  bucket = "alfaazterraformproject"

}

/*resource "aws_s3_bucket_ownership_controls" "my-s3-bucket" {
  bucket = aws_s3_bucket.my-s3-bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "my-s3-bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.example]

  bucket = aws_s3_bucket.my-s3-bucket.id
  acl = "private"
} */

resource "aws_s3_bucket_ownership_controls" "my-s3-bucket" {
  bucket = aws_s3_bucket.my-s3-bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}


resource "aws_s3_bucket_public_access_block" "my-s3-bucket" {
  bucket = aws_s3_bucket.my-s3-bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "my-s3-bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.my-s3-bucket,
    aws_s3_bucket_public_access_block.my-s3-bucket
  ]

  bucket = aws_s3_bucket.my-s3-bucket.id
  acl    = "public-read"

}

resource "aws_instance" "my-web-server1" {
  ami                    = "ami-03bb6d83c60fc5f7c"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my-web-Sg.id]
  subnet_id              = aws_subnet.my-subnet1.id
  user_data_base64       = base64encode(file("userdata.sh"))
}

resource "aws_instance" "my-web-server2" {
  ami                    = "ami-03bb6d83c60fc5f7c"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my-web-Sg.id]
  subnet_id              = aws_subnet.my-subnet2.id
  user_data_base64       = base64encode(file("userdata1.sh"))
}

# Create Load Balancer 
resource "aws_lb" "my-alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"


  security_groups = [aws_security_group.my-web-Sg.id]
  subnets         = [aws_subnet.my-subnet1.id, aws_subnet.my-subnet2.id]

  tags = {
    Name = "web"
  }

}
# Create Target group
resource "aws_lb_target_group" "tg" {
  name     = "my-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }

}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.my-web-server1.id
  port             = 80

}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.my-web-server2.id
  port             = 80

}

resource "aws_lb_listener" "my-lb-listener" {
  load_balancer_arn = aws_lb.my-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }

}

output "loadbalancer" {
  value = aws_lb.my-alb.dns_name

}