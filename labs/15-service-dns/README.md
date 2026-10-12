# Lab 15 — Service DNS

Level: Networking foundations

## Objective
Practise Service selectors, port mapping, ready endpoints, and in-cluster DNS resolution.

## Start
```bash
./scripts/lab-start.sh 15
```
Work in namespace `lab-15`.

## Four basic challenges
1. Create Service `dns-a` selecting `app=app-a`, Service port 80, and targetPort 80.
2. Create Service `dns-b` selecting `app=app-b`, Service port 80, and targetPort 80.
3. Create Service `dns-c` selecting `app=app-c`, Service port 80, and targetPort 80.
4. Create Service `dns-d` selecting `app=app-d`, Service port 80, and targetPort 80.

## Four hard challenges (HC)
The setup pre-creates these Services with intentional defects. Repair them without replacing the Deployments:
1. Repair `hc-dns-e` so it selects `app=app-e`, uses port 80 and targetPort 80, and has ready endpoints and resolves through cluster DNS.
2. Repair `hc-dns-f` so it selects `app=app-f`, uses port 80 and targetPort 80, and has ready endpoints and resolves through cluster DNS.
3. Repair `hc-dns-g` so it selects `app=app-g`, uses port 80 and targetPort 80, and has ready endpoints and resolves through cluster DNS.
4. Repair `hc-dns-h` so it selects `app=app-h`, uses port 80 and targetPort 80, and has ready endpoints and resolves through cluster DNS.

## DNS diagnostics
```bash
kubectl -n lab-15 exec dns-client -- nslookup dns-a
kubectl -n lab-15 exec dns-client -- nslookup dns-a.lab-15.svc.cluster.local
kubectl -n lab-15 exec dns-client -- cat /etc/resolv.conf
kubectl -n kube-system get pods -o wide
```
## Verify
```bash
./scripts/lab-verify.sh 15
```
The verifier reads structured API fields, requires ready endpoint addresses, and performs actual DNS lookups from an in-cluster client.

## Troubleshooting
```bash
kubectl -n lab-15 get deploy,pods,svc,endpointslices
kubectl -n lab-15 get pods --show-labels
kubectl -n lab-15 describe service <name>
```
Reset: `./scripts/lab-reset.sh 15`. Spoilers are in `solution.md`.
