provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# =====================================================
# VPC Configuration
# =====================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs            = local.azs
  public_subnets = var.public_subnet_cidrs

  enable_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

# =====================================================
# Security Groups
# =====================================================

resource "aws_security_group" "k3s" {
  name        = "${var.cluster_name}-k3s-sg"
  description = "Security group for k3s cluster"
  vpc_id      = module.vpc.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
    description = "SSH access"
  }

  # Kubernetes API
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.api_allowed_cidrs
    description = "Kubernetes API"
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP traffic"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS traffic"
  }

  # k3s internal communication
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Internal cluster communication"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.cluster_name}-k3s-sg"
  }
}

# =====================================================
# IAM Role for EC2 Instances
# =====================================================

resource "aws_iam_role" "k3s_node" {
  name = "${var.cluster_name}-k3s-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# DynamoDB access for the API
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.cluster_name}-dynamodb-access"
  role = aws_iam_role.k3s_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:*:table/patrn-*",
          "arn:aws:dynamodb:${var.aws_region}:*:table/patrn-*/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k3s_node" {
  name = "${var.cluster_name}-k3s-node-profile"
  role = aws_iam_role.k3s_node.name
}

# =====================================================
# SSH Key Pair
# =====================================================

resource "aws_key_pair" "k3s" {
  count      = var.ssh_public_key != "" ? 1 : 0
  key_name   = "${var.cluster_name}-k3s-key"
  public_key = var.ssh_public_key
}

# =====================================================
# k3s Server (Control Plane)
# =====================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "aws_instance" "k3s_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.server_instance_type
  key_name               = var.ssh_public_key != "" ? aws_key_pair.k3s[0].key_name : null
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.k3s_node.name

  associate_public_ip_address = true

  root_block_device {
    volume_size = var.server_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/k3s-server.sh", {
    k3s_token       = random_password.k3s_token.result
    k3s_version     = var.k3s_version
    cluster_name    = var.cluster_name
    install_traefik = var.install_traefik
  }))

  tags = {
    Name = "${var.cluster_name}-k3s-server"
    Role = "server"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# =====================================================
# k3s Agents (Worker Nodes) - Optional
# =====================================================

resource "aws_instance" "k3s_agent" {
  count = var.agent_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.agent_instance_type
  key_name               = var.ssh_public_key != "" ? aws_key_pair.k3s[0].key_name : null
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id              = module.vpc.public_subnets[count.index % length(module.vpc.public_subnets)]
  iam_instance_profile   = aws_iam_instance_profile.k3s_node.name

  associate_public_ip_address = true

  root_block_device {
    volume_size = var.agent_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/k3s-agent.sh", {
    k3s_token   = random_password.k3s_token.result
    k3s_version = var.k3s_version
    server_ip   = aws_instance.k3s_server.private_ip
  }))

  tags = {
    Name = "${var.cluster_name}-k3s-agent-${count.index + 1}"
    Role = "agent"
  }

  depends_on = [aws_instance.k3s_server]

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# =====================================================
# Elastic IP for stable ingress
# =====================================================

resource "aws_eip" "k3s_server" {
  instance = aws_instance.k3s_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.cluster_name}-k3s-eip"
  }
}

# =====================================================
# Null resource to wait for k3s initialization
# =====================================================

resource "null_resource" "wait_for_k3s" {
  depends_on = [aws_instance.k3s_server]

  provisioner "local-exec" {
    command = "echo 'Waiting for k3s to initialize...'"
  }
}

# =====================================================
# Cloudflare Configuration (CDN + DNS)
# =====================================================

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Root domain pointing to k3s server EIP
resource "cloudflare_dns_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = aws_eip.k3s_server.public_ip
  type    = "A"
  proxied = true # Enable Cloudflare CDN
  ttl     = 1    # Auto when proxied
}

# WWW subdomain pointing to root (proxied through Cloudflare CDN)
resource "cloudflare_dns_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = var.domain_name
  type    = "CNAME"
  proxied = true
  ttl     = 1
}

# Cloudflare Redirect Rule: www to non-www
resource "cloudflare_ruleset" "www_redirect" {
  zone_id     = var.cloudflare_zone_id
  name        = "WWW to non-WWW redirect"
  description = "Redirect www.patrn.ink to patrn.ink"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"
  rules = [
    {
      action      = "redirect"
      expression  = "(http.host eq \"www.${var.domain_name}\")"
      description = "Redirect www to non-www"
      enabled     = true
      action_parameters = {
        from_value = {
          status_code = 301
          target_url = {
            expression = "concat(\"https://${var.domain_name}\", http.request.uri.path)"
          }
          preserve_query_string = true
        }
      }
    }
  ]
}

# Cloudflare SSL/TLS settings

resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "ssl"
  value      = "full" # Use "full" since we have self-signed certs on k3s
}

resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "min_tls_version" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}

resource "cloudflare_zone_setting" "automatic_https_rewrites" {
  zone_id    = var.cloudflare_zone_id
  setting_id = "automatic_https_rewrites"
  value      = "on"
}

