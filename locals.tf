locals {
  name_prefix = lower("${var.project_name}-${var.environment}")

  selected_azs = length(var.availability_zones) == 2 ? var.availability_zones : slice(
    data.aws_availability_zones.available.names,
    0,
    2
  )

  rabbitmq_amqps_endpoint = try(
    one([
      for endpoint in aws_mq_broker.rabbitmq.instances[0].endpoints :
      endpoint if startswith(endpoint, "amqps://")
    ]),
    aws_mq_broker.rabbitmq.instances[0].endpoints[0]
  )

  rabbitmq_hostname = split(
    ":",
    trimprefix(local.rabbitmq_amqps_endpoint, "amqps://")
  )[0]
}
