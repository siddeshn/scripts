#!/bin/bash

# Usage: ./check_azure_dns.sh domains.txt
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <domains_file>"
    exit 1
fi

INPUT_FILE="$1"
LOCATION="westus"

echo "Checking availability of Azure domains..."
while read -r fqdn; do
    [[ -z "$fqdn" ]] && continue

    if [[ "$fqdn" == *.trafficmanager.net ]]; then
        label="${fqdn%%.trafficmanager.net}"
        available=$(az network traffic-manager profile check-dns \
            --name "$label" \
            --query nameAvailable -o tsv 2>/dev/null)

    elif [[ "$fqdn" == *.cloudapp.azure.com ]]; then
        label=$(echo "$fqdn" | cut -d. -f1)
        region=$(echo "$fqdn" | sed -E 's/^[^.]+\.([^.]+)\.cloudapp\.azure\.com/\1/')
        available=$(az network public-ip check-dns-availability \
            --domain-name-label "$label" \
            --location "$region" \
            --query available -o tsv 2>/dev/null)

    elif [[ "$fqdn" == *.azurewebsites.net ]]; then
        result=$(az webapp list --query "[?defaultHostName=='$fqdn']" -o tsv 2>/dev/null)
        if [[ -z "$result" ]]; then
            available="true"
        else
            available="false"
        fi

    elif [[ "$fqdn" == *.azurefd.net ]]; then
        result=$(az network front-door check-custom-domain --host-name "$fqdn" 2>/dev/null)
        if echo "$result" | grep -q '"customDomainValidated": true'; then
            available="false"
        else
            available="true"
        fi

    elif [[ "$fqdn" == *.azure-api.net ]]; then
        result=$(az apim list --query "[?gatewayUrl=='https://$fqdn']" -o tsv 2>/dev/null)
        if [[ -z "$result" ]]; then
            available="true"
        else
            available="false"
        fi

    else
        echo "Skipping unsupported domain: $fqdn"
        continue
    fi

    if [[ "$available" == "true" ]]; then
        echo "$fqdn is AVAILABLE"
    else
        echo "$fqdn is NOT available"
    fi

done < "$INPUT_FILE"
