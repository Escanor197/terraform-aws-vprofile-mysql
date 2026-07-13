resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Public HTTP access to the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tomcat" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward HTTP traffic to Tomcat"
  from_port                    = var.tomcat_port
  to_port                      = var.tomcat_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.tomcat.id
}

resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Restricted SSH access to the bastion host"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-bastion-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from the administrator public IP"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  description       = "Bastion outbound access"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "tomcat" {
  name        = "${local.name_prefix}-tomcat-sg"
  description = "Tomcat access from the ALB and SSH from the bastion"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-tomcat-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "tomcat_from_alb" {
  security_group_id            = aws_security_group.tomcat.id
  description                  = "Tomcat HTTP from the ALB"
  from_port                    = var.tomcat_port
  to_port                      = var.tomcat_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "tomcat_ssh_from_bastion" {
  security_group_id            = aws_security_group.tomcat.id
  description                  = "SSH from the bastion"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "tomcat_all" {
  security_group_id = aws_security_group.tomcat.id
  description       = "Tomcat outbound access through NAT and to private services"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-mysql-sg"
  description = "MySQL access from Tomcat and the bastion"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-mysql-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_tomcat" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from Tomcat"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.tomcat.id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_bastion" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL administration and data import from the bastion"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  description       = "RDS response traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "memcached" {
  name        = "${local.name_prefix}-memcached-sg"
  description = "Memcached access from Tomcat"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-memcached-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "memcached_from_tomcat" {
  security_group_id            = aws_security_group.memcached.id
  description                  = "Memcached from Tomcat"
  from_port                    = 11211
  to_port                      = 11211
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.tomcat.id
}

resource "aws_vpc_security_group_egress_rule" "memcached_all" {
  security_group_id = aws_security_group.memcached.id
  description       = "Memcached response traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "rabbitmq" {
  name        = "${local.name_prefix}-rabbitmq-sg"
  description = "Secure AMQP access from Tomcat"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-rabbitmq-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rabbitmq_amqps_from_tomcat" {
  security_group_id            = aws_security_group.rabbitmq.id
  description                  = "AMQPS from Tomcat"
  from_port                    = 5671
  to_port                      = 5671
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.tomcat.id
}

resource "aws_vpc_security_group_egress_rule" "rabbitmq_all" {
  security_group_id = aws_security_group.rabbitmq.id
  description       = "RabbitMQ response traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
