#!/bin/bash

AMI_ID="ami-0220d79f3f480ecf5"
SG_ID="sg-0668b48020a3df8ef"

for instance in $@
do
    INSTANCE_ID=$(aws ec2 run-instances --image-id ami-0220d79f3f480ecf5 --instance-type t3.micro --security-group-ids sg-0668b48020a3df8ef --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" --query 'Instances[0].InstanceId' --output text)

    # Get Private IP of the instance.
    if [ $instance != "frontend" ]; then
        PRIVATE_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
        echo "Private IP of the Instance $instance is: $PRIVATE_IP"
    else
        PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
        echo "Public IP of the Instance $instance is: $PUBLIC_IP"
    fi
done