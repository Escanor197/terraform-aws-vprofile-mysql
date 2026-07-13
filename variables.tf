variable "aws_region" {
  description = "AWS Region in which the infrastructure will be created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "vprofile"
}

variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string
  default     = "dev"
}

variable "availability_zones" {
  description = "Optional list of exactly two Availability Zones. Leave empty to use the first two available AZs."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) == 2
    error_message = "availability_zones must be empty or contain exactly two Availability Zones."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "public_subnet_cidrs must contain exactly two CIDR blocks."
  }
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for the two private application subnets."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_app_subnet_cidrs) == 2
    error_message = "private_app_subnet_cidrs must contain exactly two CIDR blocks."
  }
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for the two isolated private data subnets."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]

  validation {
    condition     = length(var.private_data_subnet_cidrs) == 2
    error_message = "private_data_subnet_cidrs must contain exactly two CIDR blocks."
  }
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the selected AWS Region."
  type        = string
}

variable "admin_cidr" {
  description = "Administrator public IPv4 address in CIDR form, for example 203.0.113.10/32."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr must be a valid CIDR block."
  }
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host."
  type        = string
  default     = "t3.micro"
}

variable "tomcat_instance_type" {
  description = "EC2 instance type for each Tomcat server."
  type        = string
  default     = "t3.small"
}

variable "tomcat_instance_count" {
  description = "Number of private Tomcat EC2 instances."
  type        = number
  default     = 2

  validation {
    condition     = var.tomcat_instance_count == 2
    error_message = "This project is designed for exactly two Tomcat instances."
  }
}

variable "tomcat_port" {
  description = "Tomcat HTTP connector port."
  type        = number
  default     = 8080
}

variable "db_name" {
  description = "Initial MySQL database name."
  type        = string
  default     = "accounts"
}

variable "db_username" {
  description = "RDS for MySQL master username."
  type        = string
  default     = "root"
}

variable "db_password" {
  description = "RDS for MySQL master password. Keep it out of source control."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "db_password must be at least 8 characters."
  }
}

variable "db_instance_class" {
  description = "RDS for MySQL DB instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "RDS for MySQL major/minor engine version."
  type        = string
  default     = "8.4"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Create the RDS instance as a Multi-AZ deployment."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Enable RDS deletion protection. Recommended for production."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip the final RDS snapshot during destroy. Suitable for labs only."
  type        = bool
  default     = true
}

variable "cache_node_type" {
  description = "ElastiCache Memcached node type."
  type        = string
  default     = "cache.t3.micro"
}

variable "cache_node_count" {
  description = "Number of Memcached nodes. The legacy application uses one direct node endpoint."
  type        = number
  default     = 1

  validation {
    condition     = var.cache_node_count == 1
    error_message = "This project uses one Memcached node because the application is not configured for Auto Discovery."
  }
}

variable "mq_username" {
  description = "Amazon MQ for RabbitMQ application username."
  type        = string
  default     = "rabbitadmin"
}

variable "mq_password" {
  description = "Amazon MQ for RabbitMQ password. Keep it out of source control."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mq_password) >= 12
    error_message = "mq_password must be at least 12 characters."
  }
}

variable "mq_instance_type" {
  description = "Amazon MQ RabbitMQ broker instance type."
  type        = string
  default     = "mq.m7g.medium"
}

variable "mq_engine_version" {
  description = "Amazon MQ RabbitMQ engine version."
  type        = string
  default     = "3.13"
}

variable "private_dns_zone" {
  description = "Route 53 private hosted-zone name used by the application."
  type        = string
  default     = "vprofile"
}

variable "additional_tags" {
  description = "Additional tags applied to all supported resources."
  type        = map(string)
  default     = {}
}
