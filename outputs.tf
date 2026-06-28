output "lb_ip" {
  description = "Internal IP address of the load balancer — the entry point for perimeter server traffic."
  value       = module.load_balancer.forwarding_rule_ip
}

output "instance_group_url" {
  description = "MIG instance group URL."
  value       = module.autoscaling.instance_group_url
}

output "service_account_email" {
  description = "Email of the VM service account."
  value       = module.autoscaling.service_account_email
}
