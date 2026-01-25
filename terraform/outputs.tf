output "cluster_name" {
  value       = var.cluster_name
  description = "k3s cluster name."
}

output "server_public_ip" {
  value       = aws_eip.k3s_server.public_ip
  description = "Public IP of the k3s server (Elastic IP)."
}

output "server_private_ip" {
  value       = aws_instance.k3s_server.private_ip
  description = "Private IP of the k3s server."
}

output "agent_public_ips" {
  value       = aws_instance.k3s_agent[*].public_ip
  description = "Public IPs of k3s agent nodes."
}

output "cloudflare_root_record" {
  value       = cloudflare_dns_record.root.name
  description = "Cloudflare DNS record for root domain."
}

output "ssh_command" {
  value       = var.ssh_public_key != "" ? "ssh ubuntu@${aws_eip.k3s_server.public_ip}" : "Use AWS SSM Session Manager to connect"
  description = "Command to SSH into the k3s server."
}

output "kubeconfig_command" {
  value       = var.ssh_public_key != "" ? "scp ubuntu@${aws_eip.k3s_server.public_ip}:/etc/rancher/k3s/k3s.yaml ./kubeconfig.yaml && sed -i 's/127.0.0.1/${aws_eip.k3s_server.public_ip}/g' ./kubeconfig.yaml" : "Use AWS SSM to retrieve kubeconfig from /etc/rancher/k3s/k3s.yaml"
  description = "Command to retrieve kubeconfig from k3s server."
}

output "k3s_token_note" {
  value       = "k3s token is stored in Terraform state. Use 'terraform output -raw k3s_token' if needed."
  description = "Note about k3s token storage."
}

output "estimated_monthly_cost" {
  value       = "~$15-25/month for single t3.small node (vs ~$75+ for EKS)"
  description = "Estimated monthly cost comparison."
}
