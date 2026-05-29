#!/bin/bash

AMI_ID="ami-0220d79f3f480ecf5"
SG_ID="sg-0668b48020a3df8ef"
ZONE_ID="Z031697215LI2TC1B66AG"
DOMAIN_NAME="ankar.space"

for instance in "$@"
do
    INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type t3.micro --security-group-ids "$SG_ID" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value="$instance"}]" --query 'Instances[0].InstanceId' --output text)

    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

    # Get Private IP of the instance.
    if [ "$instance" != "frontend" ]; then
        IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
        echo "Private IP of the Instance "$instance" is: "$IP""
        RECORD_NAME="$instance.$DOMAIN_NAME"
        IP_TYPE="(Private)"

    else
        IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
        echo "Public IP of the Instance "$instance" is: "$IP""
        RECORD_NAME="$DOMAIN_NAME"
        IP_TYPE="(Public)"
    fi
        # Update the DNS record in Route53
        aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"'"$RECORD_NAME"'","Type":"A","TTL":1,"ResourceRecords":[{"Value":"'"$IP"'"}]}}]}' &>>/dev/null
        echo "Updated Route53 Record: "$RECORD_NAME" → For The Instance "$instance":"$IP $IP_TYPE\n""
done