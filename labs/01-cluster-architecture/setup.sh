# Lab 01 setup — inspection-only lab, nothing to deploy.
# The namespace is already created by lab-start.sh.
info "Lab 01 is an inspection lab. Open an SSM session to the control-plane:"
info "  aws ssm start-session --region \${AWS_REGION} --target \$(cp_instance_id)"
info "Then investigate the cluster as described in README.md section 4."
