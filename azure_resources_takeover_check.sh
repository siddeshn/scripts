#!/bin/bash

# Usage: ./check_azure_dns.sh domains.txt
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <domains_file>"
    exit 1
fi

INPUT_FILE="$1"

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
        label="${fqdn%%.azurewebsites.net}"
        available=$(az rest --method post \
            --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/providers/Microsoft.Web/checkNameAvailability?api-version=2022-03-01" \
            --body "{ \"name\": \"$label\", \"type\": \"Microsoft.Web/sites\" }" \
            --query nameAvailable -o tsv 2>/dev/null)

    elif [[ "$fqdn" == *.azurefd.net ]]; then
        label="${fqdn%%.azurefd.net}"
        available=$(az network front-door check-dns-availability \
            --name "$label" \
            --query nameAvailable -o tsv 2>/dev/null)

    elif [[ "$fqdn" == *.azure-api.net ]]; then
        label="${fqdn%%.azure-api.net}"
        available=$(az apim check-name-availability \
            --name "$label" \
            --query nameAvailable -o tsv 2>/dev/null)

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
