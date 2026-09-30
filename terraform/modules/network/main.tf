###############################################################################
# VPC + Internet Gateway
###############################################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

###############################################################################
# Subnets (public + private, one per AZ)
###############################################################################

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.project_name}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
    Tier                     = "public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                              = "${var.project_name}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
    Tier                              = "private"
  }
}

###############################################################################
# NAT Gateway(s) — toggleable for cost control
###############################################################################

locals {
  nat_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0
}

resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index}"
  }
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-${count.index}"
  }

  depends_on = [aws_internet_gateway.this]
}

###############################################################################
# Route tables
###############################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table per private subnet so each can point at the
# appropriate NAT (or share the single NAT).
resource "aws_route_table" "private" {
  count  = length(aws_subnet.private)
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-private-rt-${count.index}"
  }
}

resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? length(aws_subnet.private) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # If single NAT, everyone uses NAT 0; otherwise map subnet index -> NAT index.
  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

###############################################################################
# Security groups (least privilege)
###############################################################################

# Control-plane SG
resource "aws_security_group" "control_plane" {
  name        = "${var.project_name}-control-plane"
  description = "Kubernetes control-plane node"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-control-plane-sg"
  }
}

# Worker SG
resource "aws_security_group" "worker" {
  name        = "${var.project_name}-worker"
  description = "Kubernetes worker nodes"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-worker-sg"
  }
}

# ---- Cluster port reference (informational) ----
# The rules further below allow all traffic strictly BETWEEN the two cluster
# security groups, which covers every port the cluster needs plus the Calico
# overlay. For reference, the key ports are:
#   control-plane: 6443 apiserver, 2379-2380 etcd, 10250 kubelet,
#                  10257 controller-manager, 10259 scheduler
#   workers:       10250 kubelet, 30000-32767 NodePort
#   Calico:        179/tcp BGP, 4789/udp VXLAN, 5473/tcp Typha, IP-in-IP (proto 4)

# NodePort range reachable from anywhere inside the VPC (distinct source: CIDR,
# so callers that are not cluster nodes -- e.g. a future bastion -- can reach
# NodePort services for testing).
resource "aws_vpc_security_group_ingress_rule" "worker_nodeport" {
  security_group_id = aws_security_group.worker.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = tonumber(split("-", var.nodeport_range)[0])
  to_port           = tonumber(split("-", var.nodeport_range)[1])
  description       = "NodePort range (intra-VPC)"
}

# ---- Calico CNI between cluster nodes ----
# Calico needs: BGP 179/tcp, VXLAN 4789/udp, Typha 5473/tcp, and IP-in-IP
# (protocol 4). Because IP-in-IP and the full overlay are awkward to enumerate
# port-by-port and Calico health/felix use several ephemeral paths, we allow
# all traffic strictly BETWEEN the two cluster security groups. This is scoped
# to the SGs only (never the internet) and is the documented Calico approach.
resource "aws_vpc_security_group_ingress_rule" "cp_calico_from_worker" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.worker.id
  ip_protocol                  = "-1"
  description                  = "All cluster traffic from workers (Calico overlay, pods)"
}

resource "aws_vpc_security_group_ingress_rule" "worker_calico_from_cp" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.control_plane.id
  ip_protocol                  = "-1"
  description                  = "All cluster traffic from control-plane (Calico overlay, pods)"
}

resource "aws_vpc_security_group_ingress_rule" "worker_calico_self" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.worker.id
  ip_protocol                  = "-1"
  description                  = "All cluster traffic worker-to-worker (Calico overlay, pods)"
}

resource "aws_vpc_security_group_ingress_rule" "cp_calico_self" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.control_plane.id
  ip_protocol                  = "-1"
  description                  = "All cluster traffic control-plane self"
}

# ---- Egress: allow all outbound (needed for image/package pulls via NAT) ----
resource "aws_vpc_security_group_egress_rule" "cp_egress" {
  security_group_id = aws_security_group.control_plane.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound"
}

resource "aws_vpc_security_group_egress_rule" "worker_egress" {
  security_group_id = aws_security_group.worker.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound"
}
