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

## 5. Expected Outcome

- CronJob `ticker` exists in `lab-13`.
- It has spawned at least one Job (`status.lastScheduleTime` is set and/or child
  Jobs exist).
- `spec.suspend` is `true`, so no further Jobs are created.

## 6. Verification Criteria

```bash
./scripts/lab-verify.sh 13
```

Passes when:
- CronJob `ticker` exists in `lab-13`.
- It has spawned at least one Job (`status.lastScheduleTime` present OR child
  Jobs exist).
- `spec.suspend == true`.

## 7. Optional Hints

- `kubectl create cronjob ticker --image=busybox:1.36 --schedule="*/1 * * * *"
  -- sh -c "echo hello"` scaffolds it in one line.
- `kubectl get cronjob` shows SCHEDULE, SUSPEND, ACTIVE, and LAST SCHEDULE.
- A CronJob can be paused without deletion by flipping a single boolean field in
  its spec; `kubectl patch` is a convenient way to set it.

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
