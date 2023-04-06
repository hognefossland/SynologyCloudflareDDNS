#!/bin/bash
set -e;

ipv4Regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"

# DSM Config
username="$1"
password="$2"
hostname="$3"
ipAddr="$4"

# Check IP address is v4
if [[ ! $ipAddr =~ $ipv4Regex ]]
then
    echo "$ipAddr is not a valid IPv4 address";
    exit 1;
fi

# Retrieve existing entry
res=$(curl -s -X GET \
 "https://api.cloudflare.com/client/v4/zones/${username}/dns_records?name=${hostname}" \
 -H "Authorization: Bearer $password" \
 -H "Content-Type:application/json")

resSuccess=$(echo $res | jq -r ".success")
if [[ $resSuccess != "true" ]]
then
    echo "badauth";
    exit 1;
fi

resultCount=$(echo "$res" | jq -r ".result_info.count")

if [[ $resultCount = 0 ]]
then
    # Create DNS entry (disable proxy and set TTL to 900 initially)
    res=$(curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/${username}/dns_records" \
        -H "Authorization: Bearer $password" \
        -H "Content-Type:application/json" \
        --data "{\"type\":\"A\",\"name\":\"$hostname\",\"content\":\"$ipAddr\",\"proxied\":false,\"ttl\":900}")

    if [[ $resSuccess = true ]]
    then
        echo "Created DNS record ${hostname} with IP address $ipAddr."
        exit 0;
    else
        echo "Failed to create DNS record ${hostname} with IP address $ipAddr."
        exit 1;
    fi
fi

# Extract current details from the existing DNS entry
recordId=$(echo "$res" | jq -r ".result[0].id")
recordIp=$(echo "$res" | jq -r ".result[0].content")
recordProx=$(echo "$res" | jq -r ".result[0].proxied")
recordTtl=$(echo "$res" | jq -r ".result[0].ttl")

if [[ $recordIp = "$ipAddr" ]]
then
    echo "DNS record ${hostname} already has the correct IP address $recordIp."
    exit 0;
fi

# Update existing DNS entry
res=$(curl -s -X PUT \
    "https://api.cloudflare.com/client/v4/zones/${username}/dns_records/${recordId}" \
    -H "Authorization: Bearer $password" \
    -H "Content-Type:application/json" \
    --data "{\"type\":\"A\",\"name\":\"$hostname\",\"content\":\"$ipAddr\",\"proxied\":$recordProx,\"ttl\":$recordTtl}")

resSuccess=$(echo "$res" | jq -r ".success")

if [[ $resSuccess = true ]]
then
    echo "Updated DNS record ${hostname} with IP address $ipAddr (previously $recordIp)."
    exit 0;
else
    echo "Failed to update DNS record ${hostname} with IP address $ipAddr (currently $recordIp)."
    exit 1;
fi
