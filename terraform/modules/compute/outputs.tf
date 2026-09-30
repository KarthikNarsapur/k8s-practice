output "control_plane_instance_id" {
  value = aws_instance.control_plane.id
}

output "control_plane_private_ip" {
  value = aws_instance.control_plane.private_ip
}

output "worker_instance_ids" {
  value = aws_instance.worker[*].id
}

output "worker_private_ips" {
  value = aws_instance.worker[*].private_ip
}
