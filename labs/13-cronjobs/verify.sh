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

###############################################################################
# Hard Challenge checks
###############################################################################

# HC1 — slow-tick: exists and has spawned at least one Job.
if ! kc "get cronjob slow-tick -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC1] CronJob 'slow-tick' not found"
  err "Object: cronjob/slow-tick in namespace ${NS}"
  err "Hint: This CronJob should have been deployed by lab-start. Re-run the setup if needed."
  return 1
fi
st_last="$(kc "get cronjob slow-tick -n ${NS} -o jsonpath={.status.lastScheduleTime}" 2>/dev/null | tr -d '[:space:]')"
st_jobs="$(kc "get jobs -n ${NS} --no-headers" 2>/dev/null | grep -c 'slow-tick' || true)"
st_jobs="${st_jobs:-0}"
if [ -z "${st_last}" ] && [ "${st_jobs}" -lt 1 ]; then
  err "FAILED: [HC1] CronJob 'slow-tick' has not spawned any Job yet"
  err "Object: cronjob/slow-tick (lastScheduleTime empty, child jobs=${st_jobs})"
  err "Hint: The schedule fires once a minute — wait up to 60 seconds for the first Job to appear."
  return 1
fi
ok "PASS: [HC1] slow-tick has spawned at least one Job (lastScheduleTime='${st_last:-none}', jobs=${st_jobs})"

# HC2 — policy-allow and policy-forbid: both exist.
if ! kc "get cronjob policy-allow -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC2] CronJob 'policy-allow' not found"
  err "Object: cronjob/policy-allow in namespace ${NS}"
  err "Hint: This CronJob should have been deployed by lab-start. Re-run the setup if needed."
  return 1
fi
if ! kc "get cronjob policy-forbid -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC2] CronJob 'policy-forbid' not found"
  err "Object: cronjob/policy-forbid in namespace ${NS}"
  err "Hint: This CronJob should have been deployed by lab-start. Re-run the setup if needed."
  return 1
fi
ok "PASS: [HC2] policy-allow and policy-forbid both exist"

# HC3 — broken-cron: exists, NOT suspended, and at least one child Job succeeded.
if ! kc "get cronjob broken-cron -n ${NS}" >/dev/null 2>&1; then
  err "FAILED: [HC3] CronJob 'broken-cron' not found"
  err "Object: cronjob/broken-cron in namespace ${NS}"
  err "Hint: This CronJob was deployed suspended with a broken command. Unsuspend it and fix the command so its Jobs succeed."
  return 1
fi

bc_suspend="$(kc "get cronjob broken-cron -n ${NS} -o jsonpath={.spec.suspend}" 2>/dev/null | tr -d '[:space:]')"

if [ "${bc_suspend}" = "true" ]; then
  err "FAILED: [HC3] CronJob 'broken-cron' is still suspended"
  err "Object: cronjob/broken-cron (spec.suspend=${bc_suspend})"
  err "Hint: A suspended CronJob will not create Jobs. Toggle the boolean field that controls scheduling."
  return 1
fi

# Count successful child Jobs structurally using Kubernetes JSON output.
# A CronJob-created Job has an ownerReference pointing to the CronJob.
bc_succeeded="$(
  kc "get jobs -n ${NS} -o json" 2>/dev/null |
    python3 -c '
import json
import sys

data = json.load(sys.stdin)
count = 0

for job in data.get("items", []):
    metadata = job.get("metadata", {})

    # Ensure this is actually a child of broken-cron.
    owned_by_broken_cron = any(
        ref.get("kind") == "CronJob" and
        ref.get("name") == "broken-cron" and
        ref.get("controller") is True
        for ref in metadata.get("ownerReferences", [])
    )

    # Fallback to the generated Job name if ownerReferences are unavailable.
    name_match = metadata.get("name", "").startswith("broken-cron-")

    succeeded = job.get("status", {}).get("succeeded", 0) or 0

    if (owned_by_broken_cron or name_match) and succeeded >= 1:
        count += 1

print(count)
'
)"

bc_succeeded="${bc_succeeded:-0}"

if [ "${bc_succeeded}" -lt 1 ]; then
  err "FAILED: [HC3] CronJob 'broken-cron' has no successful child Jobs"
  err "Object: cronjob/broken-cron (succeeded child jobs=${bc_succeeded})"
  err "Hint: The original command exits non-zero. Replace it with one that succeeds, then wait for a new Job to fire."
  return 1
fi

ok "PASS: [HC3] broken-cron is unsuspended and has at least one successful child Job"
ok "PASS: Lab 13 base + hard challenges complete"
return 0
