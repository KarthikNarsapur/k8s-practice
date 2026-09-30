output "instance_profile_name" {
  value = aws_iam_instance_profile.node.name
}

output "role_arn" {
  value = aws_iam_role.node.arn
}
