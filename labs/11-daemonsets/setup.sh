# Lab 11 setup — nothing is deployed. You will create the DaemonSet yourself.
# The namespace ($NS) is already created by lab-start.sh.
info "Lab 11 deploys no starting workload."
info "Your task: create a DaemonSet 'node-agent' in namespace ${NS}."
info "First, look at how many nodes are schedulable:"
info "  kubectl get nodes -o wide"
info "See README.md section 4 for the full challenge."
