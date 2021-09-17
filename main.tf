provider "aws" {
  region = "us-west-2"
}

locals {
  name   = "vpc-example"
  region = "us-west-2"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2"

  name = local.name
  cidr = "10.0.0.0/16"

  azs                = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

resource "aws_security_group" "all_access" {
  name_prefix = "all_access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  for_each = toset( ["instance-one", "instance-two"] )
  name = each.key

  ami                    = "ami-0c2d06d50ce30b442"
  instance_type          = "t3.micro"
  key_name               = "my-key-aws"
  vpc_security_group_ids = [aws_security_group.all_access.id]
  subnet_id              = module.vpc.public_subnets[0]
  user_data_base64       = "IyEvYmluL2Jhc2gKeXVtIGluc3RhbGwgLXkgaHR0cGQKc2VydmljZSBodHRwZCBzdGFydAppbnN0YW5jZV9pZD0kKGN1cmwgaHR0cDovLzE2OS4yNTQuMTY5LjI1NC9sYXRlc3QvbWV0YS1kYXRhL2luc3RhbmNlLWlkKQplY2hvICI8aDM+SSdhbSB0aGUgaW5zdGFuY2UgJGluc3RhbmNlX2lkPC9oMz4iID4gL3Zhci93d3cvaHRtbC9pbmRleC5odG1s"
}

module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "~> 2.0"

  name = "elb-example"

  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.all_access.id]

  listener = [
    {
      instance_port     = 80
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    }
  ]

  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  number_of_instances = 2
  instances           = [module.ec2_instance["instance-one"].id, module.ec2_instance["instance-two"].id]
}