variable "cluster_name" {
  default = "flask-eks-cluster"
}
 
variable "region" {
  default = "us-east-2"
}
 
variable "vpc_id" {
  description = "Your default VPC ID"
  default     = "vpc-08235185c72819249" # your default VPC
}
variable "subnet_ids" {
  default = [
    "subnet-08c3a1ef6bb4e9d85",  # us-east-2a ✅
    "subnet-0ca5526a0666f2e63",  # us-east-2d ✅
    "subnet-07bb07bac640c7655"   # us-east-1c ✅
  ]
}
 