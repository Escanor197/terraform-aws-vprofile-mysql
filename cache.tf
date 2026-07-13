resource "aws_elasticache_subnet_group" "memcached" {
  name       = "${local.name_prefix}-cache-subnets"
  subnet_ids = aws_subnet.private_data[*].id

  tags = {
    Name = "${local.name_prefix}-cache-subnets"
  }
}

resource "aws_elasticache_cluster" "memcached" {
  cluster_id = substr("${local.name_prefix}-memcached", 0, 40)

  engine               = "memcached"
  node_type            = var.cache_node_type
  num_cache_nodes      = var.cache_node_count
  port                 = 11211
  parameter_group_name = "default.memcached1.6"

  az_mode           = "single-az"
  availability_zone = local.selected_azs[0]

  subnet_group_name  = aws_elasticache_subnet_group.memcached.name
  security_group_ids = [aws_security_group.memcached.id]

  apply_immediately = true

  tags = {
    Name = "${local.name_prefix}-memcached"
  }
}
