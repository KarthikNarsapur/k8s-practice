output "vpc_id" {
  description = "The lab VPC id."
  value       = module.network.vpc_id
}

output "control_plane_instance_id" {
  description = "Instance id of the control-plane node."
  value       = module.compute.control_plane_instance_id
}

output "worker_instance_ids" {
  description = "Instance ids of the worker nodes."
  value       = module.compute.worker_instance_ids
}

output "control_plane_private_ip" {
  description = "Private IP of the control-plane node."
  value       = module.compute.control_plane_private_ip
}

output "ssm_connect_control_plane" {
  description = "Command to open an SSM session to the control-plane node."
  value       = "aws ssm start-session --region ${var.region} --target ${module.compute.control_plane_instance_id}"
}

output "ssm_connect_workers" {
  description = "Commands to open SSM sessions to each worker node."
  value       = [for id in module.compute.worker_instance_ids : "aws ssm start-session --region ${var.region} --target ${id}"]
}

output "get_kubeconfig_hint" {
  description = "How to pull kubeconfig locally via SSM."
  value       = "See README section 'Connect'. kubeconfig lives at /etc/kubernetes/admin.conf on the control-plane; access it via an SSM session."
}

output "cost_note" {
  description = "Reminder about ongoing costs."
  value       = "Running: ~4x t3.medium + 1 NAT GW + EBS. Stop instances between sessions (scripts/aws-stop.sh) or run 'terraform destroy' to stop all charges."
}
