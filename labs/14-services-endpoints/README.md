# Lab 14 — Services and Endpoints

Level: Networking foundations

## Objective
Practise Service selectors, port mapping, ready endpoints.

## Start
```bash
./scripts/lab-start.sh 14
```
Work in namespace `lab-14`.

## Four basic challenges
1. Create Service `svc-a` selecting `app=app-a`, Service port 80, and targetPort 80.
2. Create Service `svc-b` selecting `app=app-b`, Service port 80, and targetPort 80.
3. Create Service `svc-c` selecting `app=app-c`, Service port 80, and targetPort 80.
4. Create Service `svc-d` selecting `app=app-d`, Service port 80, and targetPort 80.

## Four hard challenges (HC)
The setup pre-creates these Services with intentional defects. Repair them without replacing the Deployments:
1. Repair `hc-svc-e` so it selects `app=app-e`, uses port 80 and targetPort 80, and has ready endpoints.
2. Repair `hc-svc-f` so it selects `app=app-f`, uses port 80 and targetPort 80, and has ready endpoints.
3. Repair `hc-svc-g` so it selects `app=app-g`, uses port 80 and targetPort 80, and has ready endpoints.
4. Repair `hc-svc-h` so it selects `app=app-h`, uses port 80 and targetPort 80, and has ready endpoints.

## Verify
```bash
./scripts/lab-verify.sh 14
```
The verifier reads structured API fields, requires ready endpoint addresses, and does not infer endpoint health from the Service object's existence.

## Troubleshooting
```bash
kubectl -n lab-14 get deploy,pods,svc,endpointslices
kubectl -n lab-14 get pods --show-labels
kubectl -n lab-14 describe service <name>
```
Reset: `./scripts/lab-reset.sh 14`. Spoilers are in `solution.md`.
