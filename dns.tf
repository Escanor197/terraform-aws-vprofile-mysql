resource "aws_route53_zone" "private" {
  name = var.private_dns_zone

  vpc {
    vpc_id     = aws_vpc.main.id
    vpc_region = var.aws_region
  }

  tags = {
    Name = "${local.name_prefix}-private-zone"
  }
}

resource "aws_route53_record" "database" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "db01.${var.private_dns_zone}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_db_instance.mysql.address]
}

resource "aws_route53_record" "memcached" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "mc01.${var.private_dns_zone}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_elasticache_cluster.memcached.cache_nodes[0].address]
}

resource "aws_route53_record" "rabbitmq" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "rmq01.${var.private_dns_zone}"
  type    = "CNAME"
  ttl     = 60
  records = [local.rabbitmq_hostname]
}
