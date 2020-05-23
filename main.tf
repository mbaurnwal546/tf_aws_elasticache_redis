data "aws_vpc" "vpc" {
  id = "${var.vpc_id}"
}

locals {
  vpc_name = "${lookup(data.aws_vpc.vpc.tags, "Name", var.vpc_id)}"
}

resource "random_id" "salt" {
  byte_length = 8

  keepers {
    redis_version = "${var.redis_version}"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  count = "${length(var.auth_token) > 0 && var.transit_encryption_enabled ? 0 : 1}"

  replication_group_id          = "${format("%.20s", "${var.name}-${var.env}")}"
  replication_group_description = "Terraform-managed ElastiCache replication group for ${var.name}-${var.env}-${local.vpc_name}"
  number_cache_clusters         = "${var.redis_clusters}"
  node_type                     = "${var.redis_node_type}"
  automatic_failover_enabled    = "${var.redis_failover}"
  auto_minor_version_upgrade    = "${var.auto_minor_version_upgrade}"
  availability_zones            = "${var.availability_zones}"
  engine                        = "redis"
  at_rest_encryption_enabled    = "${var.at_rest_encryption_enabled}"
  kms_key_id                    = "${var.kms_key_id}"
  transit_encryption_enabled    = "${var.transit_encryption_enabled}"
  engine_version                = "${var.redis_version}"
  port                          = "${var.redis_port}"
  parameter_group_name          = "${aws_elasticache_parameter_group.redis_parameter_group.id}"
  subnet_group_name             = "${aws_elasticache_subnet_group.redis_subnet_group.id}"
  security_group_names          = "${var.security_group_names}"
  security_group_ids            = ["${aws_security_group.redis_security_group.id}"]
  snapshot_arns                 = "${var.snapshot_arns}"
  snapshot_name                 = "${var.snapshot_name}"
  apply_immediately             = "${var.apply_immediately}"
  maintenance_window            = "${var.redis_maintenance_window}"
  notification_topic_arn        = "${var.notification_topic_arn}"
  snapshot_window               = "${var.redis_snapshot_window}"
  snapshot_retention_limit      = "${var.redis_snapshot_retention_limit}"
  tags                          = "${merge(map("Name", format("tf-elasticache-%s-%s", var.name, local.vpc_name)), var.tags)}"
}

resource "aws_elasticache_replication_group" "redis_auth" {
  count = "${length(var.auth_token) > 0 && var.transit_encryption_enabled ? 1 : 0}"

  replication_group_id          = "${format("%.20s", "${var.name}-${var.env}")}"
  replication_group_description = "Terraform-managed ElastiCache replication group for ${var.name}-${var.env}-${local.vpc_name}"
  number_cache_clusters         = "${var.redis_clusters}"
  node_type                     = "${var.redis_node_type}"
  automatic_failover_enabled    = "${var.redis_failover}"
  auto_minor_version_upgrade    = "${var.auto_minor_version_upgrade}"
  availability_zones            = "${var.availability_zones}"
  engine                        = "redis"
  at_rest_encryption_enabled    = "${var.at_rest_encryption_enabled}"
  kms_key_id                    = "${var.kms_key_id}"
  transit_encryption_enabled    = "${var.transit_encryption_enabled}"
  auth_token                    = "${var.auth_token}"
  engine_version                = "${var.redis_version}"
  port                          = "${var.redis_port}"
  parameter_group_name          = "${aws_elasticache_parameter_group.redis_parameter_group.id}"
  subnet_group_name             = "${aws_elasticache_subnet_group.redis_subnet_group.id}"
  security_group_names          = "${var.security_group_names}"
  security_group_ids            = ["${aws_security_group.redis_security_group.id}"]
  snapshot_arns                 = "${var.snapshot_arns}"
  snapshot_name                 = "${var.snapshot_name}"
  apply_immediately             = "${var.apply_immediately}"
  maintenance_window            = "${var.redis_maintenance_window}"
  notification_topic_arn        = "${var.notification_topic_arn}"
  snapshot_window               = "${var.redis_snapshot_window}"
  snapshot_retention_limit      = "${var.redis_snapshot_retention_limit}"
  tags                          = "${merge(map("Name", format("tf-elasticache-%s-%s", var.name, local.vpc_name)), var.tags)}"
}

locals {
  redis_id                       = "${join("", concat(aws_elasticache_replication_group.redis.*.id, aws_elasticache_replication_group.redis_auth.*.id))}"
  redis_primary_endpoint_address = "${join("", concat(aws_elasticache_replication_group.redis.*.primary_endpoint_address, aws_elasticache_replication_group.redis_auth.*.primary_endpoint_address))}"
}

resource "aws_elasticache_parameter_group" "redis_parameter_group" {
  name = "${replace(format("%.255s", lower(replace("tf-redis-${var.name}-${var.env}-${local.vpc_name}-${random_id.salt.hex}", "_", "-"))), "/\\s/", "-")}"

  description = "Terraform-managed ElastiCache parameter group for ${var.name}-${var.env}-${local.vpc_name}"

  # Strip the patch version from redis_version var
  family    = "redis${replace(var.redis_version, "/\\.[\\d]+$/", "")}"
  parameter = "${var.redis_parameters}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${replace(format("%.255s", lower(replace("tf-redis-${var.name}-${var.env}-${local.vpc_name}", "_", "-"))), "/\\s/", "-")}"
  subnet_ids = ["${var.subnets}"]
}
