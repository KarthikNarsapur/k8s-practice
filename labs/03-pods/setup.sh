# Lab 03 setup — creation lab, nothing to deploy.
# The namespace ${NS} is already created by lab-start.sh.
info "Lab 03 has no starting workload — you will build the multi-container Pod 'web' yourself."
info "All objects go in namespace: ${NS}"
info "This requires a YAML manifest (two containers cannot be expressed with a single 'kubectl run')."
info "See README.md section 4 for the container names and images."
