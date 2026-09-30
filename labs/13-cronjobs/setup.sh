# Lab 13 setup — nothing is deployed. You will create the CronJob yourself.
# The namespace ($NS) is already created by lab-start.sh.
info "Lab 13 deploys no starting workload."
info "Your task: create a CronJob 'ticker' in namespace ${NS} (schedule '*/1 * * * *')."
info "Wait ~1 minute for it to spawn at least one Job, then suspend it."
info "See README.md section 4 for the full challenge."
