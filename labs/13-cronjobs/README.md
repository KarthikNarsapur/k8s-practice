# Lab 13 — CronJobs

Level 2: Workloads

## 1. Objective

Understand scheduled workloads: a CronJob creates a Job on a recurring cron
schedule. By the end you will be able to create a CronJob, confirm it has fired
at least once, read its history, and pause it with `spec.suspend` without
deleting it.

## 2. Prerequisites

- The cluster is deployed and all nodes are `Ready`.
- You can open an SSM session to the control-plane node (see main README).
- Completed: Lab 12 (Jobs) — a CronJob simply creates Jobs on a schedule.

## 3. Environment Setup

```bash
./scripts/lab-start.sh 13
```

This lab deploys **nothing**. You create the CronJob yourself in the `lab-13`
namespace.

## 4. Challenge

Work in the `lab-13` namespace.

1. Create a CronJob named `ticker` that:
   - uses schedule `*/1 * * * *` (every minute),
   - uses image `busybox:1.36`,
   - runs the command `echo hello`,
   - uses `restartPolicy: Never` (or `OnFailure`) in its job template.
2. **Wait roughly one minute** for it to spawn its first Job, then confirm:
   ```bash
   kubectl -n lab-13 get cronjob ticker     # LAST SCHEDULE gets populated
   kubectl -n lab-13 get jobs               # a ticker-<ts> Job appears
   kubectl -n lab-13 get pods
   kubectl -n lab-13 describe cronjob ticker
   ```
3. **Suspend** the CronJob so it stops creating new Jobs, without deleting it
   (set `spec.suspend: true`).

Note: with a one-minute schedule you may need to wait up to ~60 seconds before
the first Job appears. Be patient before verifying.

### Hard Challenges

These build on the base lab. `./scripts/lab-start.sh 13` pre-deploys the
CronJobs below. Investigate them in the `lab-13` namespace with
`kubectl -n lab-13 get cronjobs` and `kubectl -n lab-13 get jobs`.

**HC1 — Concurrent CronJobs.** Setup deploys a CronJob `slow-tick` scheduled
`*/1 * * * *` whose Job runs `sleep 90` — longer than the one-minute interval —
with `concurrencyPolicy: Allow`.
- Wait a couple of minutes and observe that a new Job starts before the previous
  one finishes, so multiple `slow-tick-*` Jobs are `ACTIVE` at once.
- Explain why `Allow` permits overlapping runs.

**HC2 — concurrencyPolicy.** Setup deploys two CronJobs with identical
long-running (`sleep 120`) jobs but different policies:
- `policy-allow` (`concurrencyPolicy: Allow`) — creates a new Job each minute
  even while the previous one is still running.
- `policy-forbid` (`concurrencyPolicy: Forbid`) — skips the next run while a
  prior Job is still active.
Watch both over a few minutes and compare how many Jobs each accumulates. This
challenge is **observational** — explain the difference in your own words.

**HC3 — CronJob Forensics.** Setup deploys a CronJob `broken-cron` that is
`suspend: true` from the start **and** has a failing command (`sh -c "exit 1"`).
- Investigate why it never runs (it is suspended).
- **Unsuspend** it (`spec.suspend: false`) **and fix** the command so its child
  Jobs exit 0, then wait for a new Job to fire and succeed.

## 5. Expected Outcome

- CronJob `ticker` exists in `lab-13`.
- It has spawned at least one Job (`status.lastScheduleTime` is set and/or child
  Jobs exist).
- `spec.suspend` is `true`, so no further Jobs are created.
- **HC1:** CronJob `slow-tick` exists and has spawned at least one Job.
- **HC2:** CronJobs `policy-allow` and `policy-forbid` both exist.
- **HC3:** CronJob `broken-cron` is unsuspended (`spec.suspend: false`) and has
  at least one successful child Job.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 13
```

Passes when:
- CronJob `ticker` exists in `lab-13`.
- It has spawned at least one Job (`status.lastScheduleTime` present OR child
  Jobs exist).
- `spec.suspend == true`.
- **HC1:** CronJob `slow-tick` exists and has spawned at least one Job.
- **HC2:** CronJobs `policy-allow` and `policy-forbid` both exist.
- **HC3:** CronJob `broken-cron` exists, `spec.suspend == false`, and at least
  one of its child Jobs has `status.succeeded >= 1`.

## 7. Optional Hints

- `kubectl create cronjob ticker --image=busybox:1.36 --schedule="*/1 * * * *"
  -- sh -c "echo hello"` scaffolds it in one line.
- `kubectl get cronjob` shows SCHEDULE, SUSPEND, ACTIVE, and LAST SCHEDULE.
- A CronJob can be paused without deletion by flipping a single boolean field in
  its spec; `kubectl patch` is a convenient way to set it.
- **HC1/HC2:** `concurrencyPolicy` governs what happens when a scheduled run
  arrives while a prior Job is still running — `Allow` lets them overlap,
  `Forbid` skips the new one, `Replace` kills the old one. Watch `ACTIVE` in
  `kubectl get cronjob`.
- **HC3:** Two separate things keep `broken-cron` from succeeding — it is paused,
  *and* its command fails. Address both: resume scheduling, and give the job
  template a command that exits 0 (the pod template lives under
  `spec.jobTemplate.spec.template.spec`).

## 8. Troubleshooting

- `LAST SCHEDULE` is `<none>` → the first minute has not elapsed yet; wait and
  re-check.
- No Jobs appear at all → confirm the schedule string is valid five-field cron
  and that the CronJob is not already suspended.
- Suspending too early → if you set `suspend: true` before the first Job fired,
  the verifier's "spawned at least one Job" check will fail; let it run once
  first, then suspend.

## 9. Solution

The full solution is in `solution.md`. Try everything above first — open it
only if you are stuck.

## 10. Cleanup / Reset

```bash
./scripts/lab-reset.sh 13     # deletes the lab-13 namespace, starts fresh
./scripts/lab-destroy.sh 13   # removes lab state entirely
```
