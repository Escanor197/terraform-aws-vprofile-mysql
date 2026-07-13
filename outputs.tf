output "vpc_id" {
  description = "ID of the project VPC."
  value       = aws_vpc.main.id
}

output "selected_availability_zones" {
  description = "Availability Zones used by the project."
  value       = local.selected_azs
}

output "bastion_public_ip" {
  description = "Elastic IP address of the bastion host."
  value       = aws_eip.bastion.public_ip
}

output "tomcat_instance_ids" {
  description = "EC2 instance IDs of the private Tomcat servers."
  value       = aws_instance.tomcat[*].id
}

output "tomcat_private_ips" {
  description = "Private IP addresses of the Tomcat servers."
  value       = aws_instance.tomcat[*].private_ip
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  description = "Public HTTP URL of the application."
  value       = "http://${aws_lb.app.dns_name}"
}

output "database_private_name" {
  description = "Private Route 53 name used by Tomcat for MySQL."
  value       = aws_route53_record.database.fqdn
}

output "mysql_endpoint" {
  description = "Native RDS for MySQL hostname without the port."
  value       = aws_db_instance.mysql.address
}

output "memcached_private_name" {
  description = "Private Route 53 name used by Tomcat for Memcached."
  value       = aws_route53_record.memcached.fqdn
}

output "memcached_endpoint" {
  description = "Native ElastiCache Memcached node endpoint."
  value       = aws_elasticache_cluster.memcached.cache_nodes[0].address
}

output "rabbitmq_private_name" {
  description = "Private Route 53 name used by the TLS tunnel for RabbitMQ."
  value       = aws_route53_record.rabbitmq.fqdn
}

output "rabbitmq_amqps_endpoint" {
  description = "Secure Amazon MQ AMQP endpoint."
  value       = local.rabbitmq_amqps_endpoint
}

output "rabbitmq_hostname" {
  description = "Amazon MQ broker hostname without scheme or port."
  value       = local.rabbitmq_hostname
}

output "route53_private_zone_id" {
  description = "ID of the Route 53 private hosted zone."
  value       = aws_route53_zone.private.zone_id
}

output "ssh_proxyjump_examples" {
  description = "Example SSH commands. Replace the key path with your local PEM file."
  value = [
    for ip in aws_instance.tomcat[*].private_ip :
    "ssh -i /path/to/key.pem -J ec2-user@${aws_eip.bastion.public_ip} ec2-user@${ip}"
  ]
}
