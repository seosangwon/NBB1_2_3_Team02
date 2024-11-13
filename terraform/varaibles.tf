# variables.tf

variable "prefix" {
  description = "Prefix for all resources"
  default     = "terraform"
}

variable "region" {
  description = "AWS region"
  default     = "ap-northeast-2"
}

variable "nickname" {
  description = "Nickname for resources"
  default     = "sangwon"
}

# RDS 비밀번호를 위한 민감한 변수 추가
variable "db_password" {
  description = "Password for RDS instance"
  type        = string
  sensitive   = true
}



