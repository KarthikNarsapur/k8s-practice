#!/usr/bin/env bash
set -euo pipefail
info "Lab 16: sample workloads and four NodePort Services with intentional selector, targetPort, or nodePort defects."
remote_exec "cat <<'YAML' | kubectl apply -n ${NS} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-a
  template:
    metadata:
      labels:
        app: app-a
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-b
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-b
  template:
    metadata:
      labels:
        app: app-b
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-c
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-c
  template:
    metadata:
      labels:
        app: app-c
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-d
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-d
  template:
    metadata:
      labels:
        app: app-d
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-e
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-e
  template:
    metadata:
      labels:
        app: app-e
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-f
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-f
  template:
    metadata:
      labels:
        app: app-f
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-g
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-g
  template:
    metadata:
      labels:
        app: app-g
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-h
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-h
  template:
    metadata:
      labels:
        app: app-h
    spec:
      containers:
      - name: web
        image: nginx:1.27
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: hc-node-e
spec:
  type: NodePort
  selector:
    app: missing-e
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30095
---
apiVersion: v1
kind: Service
metadata:
  name: hc-node-f
spec:
  type: NodePort
  selector:
    app: app-f
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30086
---
apiVersion: v1
kind: Service
metadata:
  name: hc-node-g
spec:
  type: NodePort
  selector:
    app: app-g
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30097
---
apiVersion: v1
kind: Service
metadata:
  name: hc-node-h
spec:
  type: NodePort
  selector:
    app: app-h
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30088
---
YAML"
ok "Setup complete. Complete the four basic challenges and four hard challenges in README.md."
