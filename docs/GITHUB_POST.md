# GitHub Project Post

## Repository name

`terraform-aws-vprofile-mysql`

## Repository description

Terraform project for a private multi-tier AWS VProfile deployment using two Tomcat EC2 instances, an Application Load Balancer, RDS MySQL, ElastiCache Memcached, Amazon MQ RabbitMQ, Route 53 private DNS, NAT Gateway, and a bastion host.

## Suggested topics

```text
terraform
aws
infrastructure-as-code
devops
vpc
ec2
rds
mysql
tomcat
application-load-balancer
elasticache
memcached
amazon-mq
rabbitmq
route53
amazon-linux-2023
```

## Professional project announcement

🚀 **New AWS Infrastructure as Code Project: VProfile on AWS with Terraform**

I built a complete multi-tier AWS environment using Terraform to deploy the VProfile Java application with a secure and highly structured network design.

### Architecture highlights

- A custom VPC distributed across two Availability Zones
- Public subnets for an Application Load Balancer and bastion host
- Two private Tomcat EC2 instances behind the load balancer
- Amazon RDS for MySQL in isolated data subnets
- Amazon ElastiCache for Memcached
- Amazon MQ for RabbitMQ with a TLS compatibility tunnel
- Route 53 private DNS records for internal service discovery
- NAT Gateway access for package installation and application builds
- Security groups that permit only the required communication paths
- ALB sticky sessions to support the legacy Spring application session model

The repository also includes:

- A production-style Terraform file structure
- An Amazon Linux 2023 Tomcat installation and deployment script
- MySQL schema and sample data initialization
- Detailed deployment, validation, troubleshooting, and cleanup documentation

This project strengthened my hands-on experience with AWS networking, managed services, Linux administration, Java application deployment, and Infrastructure as Code.

#Terraform #AWS #DevOps #InfrastructureAsCode #EC2 #RDS #MySQL #Tomcat #RabbitMQ #ElastiCache #Route53 #CloudEngineering
