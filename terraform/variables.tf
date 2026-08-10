variable "aws_region" {}
variable "db_name" {}
variable "db_username" {}
variable "db_password" {}
 
variable "vpc_id" {}
variable "private_subnet_ids" {
  type = list(string)
}
 