variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for the VPC"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)

  validation {
    condition = (
      length(var.availability_zones) ==
      length(var.public_subnet_cidrs) &&
      length(var.public_subnet_cidrs) ==
      length(var.private_subnet_cidrs)
    )
    error_message = "availability_zones, public_subnet_cidrs, and private_subnet_cidrs must have the same length."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}