#!/bin/bash -e

if [ $# -lt 1 ]; then
    echo "usage: $0 StackName [ region ]"
    exit 1
fi

SOCAStackName=$1
shift
if [ $# -gt 0 ]; then
    export AWS_DEFAULT_REGION=$1
    shift
fi

VaultName=Vault-soca-${SOCAStackName}
if ! aws backup list-backup-vaults --query 'BackupVaultList[*].BackupVaultName' | grep $VaultName &> /dev/null; then
    echo "$VaultName doesn't exist. May have already been deleted or value name may have changed."
    VaultName=soca-${SOCAStackName}-BackupVault
    if ! aws backup list-backup-vaults --query 'BackupVaultList[*].BackupVaultName' | grep $VaultName &> /dev/null; then
        echo "$VaultName doesn't exist. May have already been deleted."
        exit 0
    fi
fi
recovery_point_arns=( $(aws backup list-recovery-points-by-backup-vault --backup-vault-name ${VaultName} --query 'RecoveryPoints[*].RecoveryPointArn' --output text) )
num="${#recovery_point_arns[@]}"
if [[ $num == 0 ]]; then
    echo "No recovery points found"
    exit 0
fi

echo "Deleting $num recovery points from $VaultName."
for recovery_point_arn in ${recovery_point_arns[@]}; do
    echo "Deleting $recovery_point_arn"
    aws backup delete-recovery-point --backup-vault-name ${VaultName} --recovery-point-arn $recovery_point_arn
done
# The cloudformation stack should delete the actual vault.
#echo -e "\nDeleting $VaultName"
#aws backup delete-backup-vault --backup-vault-name ${VaultName}
