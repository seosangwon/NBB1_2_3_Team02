# Terraform 설정 시작
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# AWS 프로바이더 설정
provider "aws" {
  region = var.region
}

# VPC 설정 시작
resource "aws_vpc" "vpc_1" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true  # DNS 지원 활성화
  enable_dns_hostnames = true  # DNS 호스트 이름 활성화

  tags = {
    Name = "${var.prefix}-vpc-1"
  }
}

# 서브넷 설정 (subnet_1, subnet_2, subnet_3)
resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true  # 인스턴스에 퍼블릭 IP 자동 할당

  tags = {
    Name = "${var.prefix}-subnet-1"
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-2"
  }
}

resource "aws_subnet" "subnet_3" {
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-3"
  }
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "igw_1" {
  vpc_id = aws_vpc.vpc_1.id

  tags = {
    Name = "${var.prefix}-igw-1"
  }
}

# 라우트 테이블 생성
resource "aws_route_table" "rt_1" {
  vpc_id = aws_vpc.vpc_1.id

  # 모든 트래픽을 인터넷 게이트웨이를 통해 라우팅
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_1.id
  }

  tags = {
    Name = "${var.prefix}-rt-1"
  }
}

# 라우트 테이블과 서브넷 연결
resource "aws_route_table_association" "association_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.rt_1.id
}

resource "aws_route_table_association" "association_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.rt_1.id
}

resource "aws_route_table_association" "association_3" {
  subnet_id      = aws_subnet.subnet_3.id
  route_table_id = aws_route_table.rt_1.id
}

# 보안 그룹 생성
resource "aws_security_group" "sg_1" {
  name        = "${var.prefix}-sg-1"
  description = "Allow HTTP/HTTPS traffic"  # SSH 접근 제거
  vpc_id      = aws_vpc.vpc_1.id

  # 인바운드 규칙: HTTP, HTTPS 허용
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTP 접근
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTPS 접근
  }

  # 아웃바운드 규칙: 모든 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-sg-1"
  }
}

# RDS 보안 그룹 생성
resource "aws_security_group" "rds_sg" {
  name        = "${var.prefix}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.vpc_1.id

  # 인바운드 규칙: EC2 인스턴스의 보안 그룹에서만 MySQL 접근 허용
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_1.id]
  }

  # 아웃바운드 규칙: 모든 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-rds-sg"
  }
}

# Route 53 호스팅 존 생성
resource "aws_route53_zone" "vpc_1_zone" {
  vpc {
    vpc_id = aws_vpc.vpc_1.id
  }
  name = "vpc-1.com"
}

# EC2 IAM 역할 생성
resource "aws_iam_role" "ec2_role_1" {
  name = "${var.prefix}-ec2-role-1"

  # EC2 서비스가 이 역할을 가정할 수 있도록 신뢰 정책 설정
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Action": "sts:AssumeRole",
      "Principal": {
          "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# IAM 역할에 정책 부착
# 기존의 AmazonEC2RoleforSSM 정책을 AmazonSSMManagedInstanceCore로 대체
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role_1.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 필요한 다른 정책 부착 (예: S3 접근)
resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.ec2_role_1.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# IAM 인스턴스 프로파일 생성
resource "aws_iam_instance_profile" "instance_profile_1" {
  name = "${var.prefix}-instance-profile-1"
  role = aws_iam_role.ec2_role_1.name
}

# EC2 User Data 스크립트 설정
locals {
  ec2_user_data_base = <<-END_OF_FILE
#!/bin/bash
yum install -y python socat mlocate docker
systemctl enable docker
systemctl start docker

# SELinux 비활성화
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
sed -i 's/^SELINUX=permissive$/SELINUX=disabled/' /etc/selinux/config

# Swap 설정
dd if=/dev/zero of=/swapfile bs=128M count=32
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile swap swap defaults 0 0" >> /etc/fstab

# mlocate 데이터베이스 업데이트
updatedb

END_OF_FILE
}

# EC2 인스턴스 생성
resource "aws_instance" "ec2_1" {
  ami                         = "ami-04b3f91ebd5bc4f6d"  # 사용할 AMI ID (Amazon Linux 2 예시)
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet_1.id
  vpc_security_group_ids      = [aws_security_group.sg_1.id]
  associate_public_ip_address = true

  # IAM 인스턴스 프로파일 연결
  iam_instance_profile = aws_iam_instance_profile.instance_profile_1.name

  # SSH 키 페어 제거 (SSH 접근 방지)
  # key_name 속성을 제거합니다.

  # 루트 볼륨 설정
  root_block_device {
    volume_type = "gp3"
    volume_size = 30  # 30GB로 설정
  }

  # User Data 스크립트
  user_data = <<-EOF
${local.ec2_user_data_base}
hostnamectl set-hostname ec2-1
EOF

  tags = {
    Name = "${var.prefix}-ec2-1"
  }
}

# EC2 인스턴스에 대한 Route 53 레코드 생성
resource "aws_route53_record" "record_ec2-1_vpc-1_com" {
  zone_id = aws_route53_zone.vpc_1_zone.zone_id
  name    = "ec2-1.vpc-1.com"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.ec2_1.public_ip]
}

# RDS 서브넷 그룹 생성
resource "aws_db_subnet_group" "db_subnet_group_1" {
  name       = "${var.prefix}-db-subnet-group-1"
  subnet_ids = [
    aws_subnet.subnet_1.id,
    aws_subnet.subnet_2.id,
    aws_subnet.subnet_3.id
  ]

  tags = {
    Name = "${var.prefix}-db-subnet-group-1"
  }
}

# RDS 인스턴스 생성
resource "aws_db_instance" "rds_1" {
  identifier             = "${var.prefix}-rds-1"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"  # 프리 티어 사용
  db_name                = "${var.prefix}_db"
  username               = "admin"
  password               = var.db_password  # 변수에서 비밀번호 가져오기
  parameter_group_name   = "default.mysql8.0"
  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group_1.name

  tags = {
    Name = "${var.prefix}-rds-1"
  }
}
