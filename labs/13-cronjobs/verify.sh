# Lab 13 verification — sourced by lab-verify.sh (has kc/remote_exec/info/ok/err).
# Contract: on success 'ok "PASS: ..."' + return 0.
#           on failure err FAILED/Object/Hint (ONE hint, no solution) + return 1.
# Use return, not exit.

# 0. CronJob exists?
if ! kc "get cronjob ticker -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: CronJob 'ticker' not found"
  err "Object: cronjob/ticker in namespace ${NS}"
  err "Hint: A CronJob creates Jobs on a schedule. Create one with schedule '*/1 * * * *'."
  return 1
fi

# 1. Has it spawned at least one Job?
#    Accept EITHER a recorded lastScheduleTime OR the presence of child Jobs.
last_sched="$(kc "get cronjob ticker -n ${NS} -o jsonpath={.status.lastScheduleTime}" | tr -d '[:space:]')"
job_count="$(kc "get jobs -n ${NS} --no-headers" 2>/dev/null | grep -c . || true)"
job_count="${job_count:-0}"
if [ -z "${last_sched}" ] && [ "${job_count}" -lt 1 ]; then
  err "FAILED: CronJob 'ticker' has not spawned any Job yet"
  err "Object: cronjob/ticker (status.lastScheduleTime empty, child jobs=${job_count})"
  err "Hint: A '*/1 * * * *' schedule fires once a minute — give it up to ~60s before it creates its first Job."
  return 1
fi
ok "PASS: cronjob/ticker has spawned at least one Job (lastScheduleTime='${last_sched:-none}', jobs=${job_count})"

# 2. Is it suspended (spec.suspend == true)?
suspend="$(kc "get cronjob ticker -n ${NS} -o jsonpath={.spec.suspend}" | tr -d '[:space:]')"
if [ "${suspend}" != "true" ]; then
  err "FAILED: CronJob 'ticker' is not suspended"
  err "Object: cronjob/ticker (spec.suspend=${suspend:-false})"
  err "Hint: A CronJob can be paused without deleting it by toggling one boolean field in its spec."
  return 1
fi
ok "PASS: cronjob/ticker is suspended (spec.suspend=true)"

ok "PASS: CronJob 'ticker' ran at least once and is now suspended"
return 0
