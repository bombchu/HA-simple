terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-4"
}

# Use the default VPC. You will have one unless you deleted it!

data "aws_vpc" "default" {
  default = true
}

# Use all subnets associated with the default VPC. By default you'll have one for each AZ... unless you deleted it!

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

## Security Group

#  For EC2 Instances, only allow traffic from port 80 on VPC CIDR (NLB can't have a SG.).
#   TODO; maybe consider moving this infra to a separate VPC if there are things we want to isolate from further.

resource "aws_security_group" "ec2_sg" {
  name   = "ec2-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP from VPC, so NLB can send to EC2s."
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = data.aws_subnets.default.ids == null ? [] : [
      data.aws_vpc.default.cidr_block
    ]
  }

  # Allow all egress
  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## Network ACL

# Allow ingress port 80, and all egress (NACLs are not stateful).

resource "aws_network_acl" "nacl" {
  vpc_id = data.aws_vpc.default.id

  ingress {
    rule_no    = 100
    protocol   = "6"         # TCP
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Remember we'd like an explicit DENY, otherwise we done goofed.
  ingress {
    rule_no    = 200
    protocol   = "-1"        # Everything
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"        # Everything
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  subnet_ids = data.aws_subnets.default.ids
}

## AMI, Ubuntu 20.04: arm64

data "aws_ami" "ubuntu_20_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (maker of Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

## Local variable for the user_data for the Launch Template.

# user_data to upgrade then install Nginx.

locals {
  boot_script = <<EOF
#!/bin/bash
set -xe

apt-get update -y
apt-get upgrade -y
apt-get install -y nginx

echo "This is Andrew Thomas's website." | tee "/var/www/html/index.nginx-debian.html"
echo "It is a proof of concept... by Andrew." | tee -a "/var/www/html/index.nginx-debian.html"

systemctl enable nginx
systemctl start nginx
EOF
}

## Launch Template with userdata for Nginx setup.

resource "aws_launch_template" "launch_template" {
  name_prefix   = "andrew-launch-template-"
  image_id      = data.aws_ami.ubuntu_20_04.id
  instance_type = "t4g.small"

  # Upgrade then install Nginx.
  user_data = base64encode(local.boot_script)

  # Remember the Security Group!
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
}

## Network Load Balancer

resource "aws_lb" "nlb" {
  name               = "andrew-nlb"
  load_balancer_type = "network"
  subnets            = data.aws_subnets.default.ids
}

# Target Group for NLB

resource "aws_lb_target_group" "nlb_tg" {
  name        = "andrew-nlb-target-group"
  port        = 80
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    protocol           = "HTTP"
    port               = "80"
    path               = "/"
    matcher            = "200"
    interval           = 15
    timeout            = 5
    unhealthy_threshold = 3
    healthy_threshold   = 5
  }
}

# Listener forwards to the target group (EC2s), this is also for NLB.

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg.arn
  }
}

## Auto Scaling Group

# Minimum size of 2 to provide basic redundancy (and HA). Maximum of 20 for now because I've a strict budget!

resource "aws_autoscaling_group" "asg" {
  name                      = "andrew-asg"
  max_size                  = 20
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.nlb_tg.arn]
  health_check_type         = "EC2"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "andrew-instance-from-asg"
    propagate_at_launch = true
  }
}

## ASG Scaling Policy

# Scaling policy: Increase ASG capacity by 1 when triggered

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "cpu-scale-up"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown              = 240
}

## CloudWatch Alarm (for ASG Scaling Policy to use).

# CW alarm for CPU >= 70%

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "asg-cpu-high"
  alarm_description   = "Alarm when average CPU >= 70%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_actions = [
    aws_autoscaling_policy.scale_up.arn
  ]
}