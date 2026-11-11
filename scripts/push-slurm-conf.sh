#!/usr/bin/env bash
# Push the slurm.conf rendered by Terraform to the head node and restart slurmctld.
# Run after changing compute_node_count or gpu_node_count:
#   terraform apply && ./scripts/push-slurm-conf.sh
set -euo pipefail

head_id="$(terraform output -raw head_instance_id)"
region="$(terraform output -raw region)"
conf_b64="$(terraform output -raw slurm_conf_b64)"

command_id="$(aws ssm send-command \
  --region "$region" \
  --instance-ids "$head_id" \
  --document-name AWS-RunShellScript \
  --comment "Update slurm.conf from Terraform" \
  --parameters "commands=[\"echo ${conf_b64} | base64 -d > /etc/slurm/slurm.conf\",\"systemctl restart slurmctld\",\"sleep 5\",\"sinfo\"]" \
  --query Command.CommandId \
  --output text)"

aws ssm wait command-executed --region "$region" --command-id "$command_id" --instance-id "$head_id"
aws ssm get-command-invocation \
  --region "$region" \
  --command-id "$command_id" \
  --instance-id "$head_id" \
  --query StandardOutputContent \
  --output text
