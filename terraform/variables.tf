variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-2"
}

variable "cluster_name" {
  description = "k3s cluster name (used for naming resources)."
  type        = string
  default     = "patrn-ink"
}

variable "k3s_version" {
  description = "k3s version to install."
  type        = string
  default     = "v1.29.0+k3s1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use."
  type        = number
  default     = 2
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# =====================================================
# k3s Server (Control Plane) Configuration
# =====================================================

variable "server_instance_type" {
  description = "EC2 instance type for k3s server (control plane)."
  type        = string
  default     = "t3.small"
}

variable "server_volume_size" {
  description = "Root volume size in GB for k3s server."
  type        = number
  default     = 30
}

# =====================================================
# k3s Agent (Worker) Configuration
# =====================================================

variable "agent_count" {
  description = "Number of k3s agent nodes. Set to 0 for single-node cluster."
  type        = number
  default     = 0
}

variable "agent_instance_type" {
  description = "EC2 instance type for k3s agents."
  type        = string
  default     = "t3.small"
}

variable "agent_volume_size" {
  description = "Root volume size in GB for k3s agents."
  type        = number
  default     = 30
}

# =====================================================
# Security Configuration
# =====================================================

variable "ssh_public_key" {
  description = "SSH public key for EC2 access. Leave empty to disable SSH key access."
  type        = string
  default     = ""
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH into instances."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "api_allowed_cidrs" {
  description = "CIDR blocks allowed to access Kubernetes API (port 6443)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# =====================================================
# k3s Options
# =====================================================

variable "install_traefik" {
  description = "Install Traefik ingress controller (built into k3s). Set to false to use nginx-ingress instead."
  type        = bool
  default     = true
}

# =====================================================
# Domain Configuration
# =====================================================

variable "domain_name" {
  description = "Root domain name (e.g., patrn.ink)."
  type        = string
  default     = "patrn.ink"
}

# =====================================================
# Cloudflare Configuration
# =====================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain."
  type        = string
  default     = ""
}
