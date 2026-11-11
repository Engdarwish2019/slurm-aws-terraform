# slurm-aws-terraform

[![ci](https://github.com/Engdarwish2019/slurm-aws-terraform/actions/workflows/ci.yml/badge.svg)](https://github.com/Engdarwish2019/slurm-aws-terraform/actions/workflows/ci.yml)
![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A51.6-7B42BC?logo=terraform)
![Slurm](https://img.shields.io/badge/Slurm-configless-0B5394)
![License](https://img.shields.io/badge/license-MIT-green)

A Slurm HPC cluster on AWS, built with Terraform. One `terraform apply` gives you a head node
with job accounting, CPU compute nodes in a cluster placement group, an optional NVIDIA GPU
partition and a shared EFS file system. There is no SSH and no public IP on any node: you get in
through AWS Systems Manager.

## Architecture

```mermaid
flowchart LR
    eng([Engineer]) -- "SSM Session Manager" --> head

    subgraph vpc["VPC 10.20.0.0/16"]
        subgraph public["Public subnet"]
            nat[NAT gateway]
        end
        subgraph private["Private subnet (no public IPs)"]
            head["head<br/>slurmctld · slurmdbd · MariaDB"]
            subgraph pg["Cluster placement group"]
                c1["compute-01<br/>slurmd"]
                c2["compute-02<br/>slurmd"]
            end
            g1["gpu-01 (optional)<br/>slurmd · NVIDIA driver"]
            efs[("EFS /shared<br/>KMS encrypted")]
        end
    end

    head -- "configless slurm.conf" --> c1 & c2 & g1
    head & c1 & c2 & g1 --- efs
    head -- "MUNGE key" --> ssm[("SSM Parameter Store<br/>SecureString + KMS")]
    ssm -- "read-only" --> c1 & c2 & g1
    private --> nat --> internet((Internet))
```

| Component | What it does |
|---|---|
| `head` | `slurmctld`, `slurmdbd` and MariaDB (localhost only). Generates the MUNGE key at first boot. |
| `compute-NN` | CPU nodes running `slurmd` in **configless** mode: they pull `slurm.conf`, `cgroup.conf` and `gres.conf` from the controller. |
| `gpu-NN` | Optional GPU partition (default `g5.xlarge`, 1x A10G). NVIDIA driver from the official CUDA repo, `Gres=gpu`, device isolation with cgroups. |
| EFS | Mounted at `/shared` on every node: user homes (`/shared/home`) and shared software (`/shared/apps`). |
| KMS key | One customer-managed key (rotation on) for EBS, EFS, the MUNGE key parameter and flow logs. |

## Design decisions

- **Secrets never touch code or Terraform state.** The head node creates the MUNGE key at boot and
  stores it as an SSM `SecureString`. Terraform only creates a placeholder (`ignore_changes`), compute
  nodes have read-only IAM access to that one parameter. The accounting DB password is generated on
  the head node and only lives in `slurmdbd.conf` (mode 0600).
- **Configless Slurm.** Only the head node holds `slurm.conf`. Adding nodes does not rebuild the existing
  ones, and `scripts/push-slurm-conf.sh` updates the controller through SSM Run Command.
- **Node shapes come from AWS.** CPU, core, thread and memory values in `slurm.conf` are read from the
  `aws_ec2_instance_type` data source, so changing the instance type keeps Slurm's node definition correct.
- **Least privilege network.** Default security group is emptied, nodes talk to each other freely,
  egress is limited to HTTP/HTTPS and NFS to EFS, and the EFS mount target only accepts NFS from the nodes.
- **SELinux stays enforcing**, IMDSv2 is required, all volumes are encrypted with the cluster key and
  VPC flow logs go to an encrypted CloudWatch log group.

## Usage

Requirements: Terraform 1.6+, AWS CLI v2 and the
[Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

```bash
cp terraform.tfvars.example terraform.tfvars   # adjust region, sizes, GPU count
terraform init
terraform apply

# open a shell on the head node (first boot takes ~5-10 minutes)
$(terraform output -raw connect)
sudo tail -f /var/log/hpc-bootstrap.log
```

Run the examples as the cluster user:

```bash
sudo -iu hpcuser
sinfo
cd ~/examples && sbatch hello.sbatch     # pre-installed: 2 nodes x 2 tasks
sacct --format=JobID,JobName,State,Elapsed,AllocTRES%40
```

The MPI and GPU job scripts are in [`examples/`](examples). Create them in the user's home
(it lives on `/shared`, so every node sees it), build the MPI program once with `mpicc`, and
submit with `sbatch`.

### Resizing

```bash
terraform apply -var compute_node_count=4
./scripts/push-slurm-conf.sh    # pushes the new slurm.conf and restarts slurmctld
```

### Remote state

Copy `backend.tf.example` to `backend.tf` to keep state in an encrypted S3 bucket with locking.

### Clean up

```bash
terraform destroy
```

The NAT gateway, EFS and instances are billed per hour, so destroy the lab when you are done.

## CI

Every push runs:

| Job | Tools |
|---|---|
| Terraform | `terraform fmt -check`, `terraform validate`, `tflint` (AWS ruleset) |
| Security | `checkov` (results uploaded to GitHub code scanning), `gitleaks` |
| Scripts | `shellcheck` on helper scripts and job examples |

## Repository layout

```text
.
├── main.tf / kms.tf / security.tf    root module: wiring, KMS key, security groups
├── modules/
│   ├── network/                      VPC, subnets, NAT, flow logs
│   ├── storage/                      EFS + backup policy
│   └── cluster/                      instances, IAM, SSM parameter, Slurm templates
├── examples/                         sbatch examples: hello, MPI, GPU
└── scripts/push-slurm-conf.sh        day-2 config push through SSM
```

## Related projects

- [ansible-hpc-roles](https://github.com/Engdarwish2019/ansible-hpc-roles): the same stack as reusable Ansible roles, for on-prem or bare metal.
- [slurm-observability](https://github.com/Engdarwish2019/slurm-observability): Prometheus, Grafana and alerts for Slurm and GPUs.

## License

MIT
