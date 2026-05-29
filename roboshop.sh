#!/bin/bash

AMI_ID=ami-0220d79f3f480ecf5
ZONE_ID=Z00196182YF3GPU65OI8D
DOMAIN_NAME=matamma.online

for instance in "$@"
do
    echo "Creating $instance instance"

    APP_SG=$(aws ec2 describe-security-groups \
        --filters Name=group-name,Values=roboshop-$instance \
        --query 'SecurityGroups[0].GroupId' \
        --output text)

    echo "Security Group ID: $APP_SG"

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type t3.micro \
        --security-group-ids sg-0358cd87046f2d652 $APP_SG \
        --subnet-id subnet-0bcdf0124041a31dc \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    echo "Instance ID: $INSTANCE_ID"

    if [ "$instance" == "frontend" ]; then
        IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[*].Instances[*].PublicIpAddress' \
            --output text)

        R53_RECORD=$DOMAIN_NAME
    else
        IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[*].Instances[*].PrivateIpAddress' \
            --output text)

        R53_RECORD="$instance.$DOMAIN_NAME"
    fi

    echo "$R53_RECORD --> $IP"

    echo "Updating Route53 Record"

    aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONE_ID \
        --change-batch "
{
    \"Comment\": \"Update A record to new IP\",
    \"Changes\": [
        {
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"$R53_RECORD\",
                \"Type\": \"A\",
                \"TTL\": 1,
                \"ResourceRecords\": [
                    {
                        \"Value\": \"$IP\"
                    }
                ]
            }
        }
    ]
}"
done