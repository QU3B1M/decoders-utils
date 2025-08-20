repo_root_marker="intelligence-data"
script_path=$(dirname "$(realpath "$0")")

while [[ "$script_path" != "/" ]] && [[ ! -d "$script_path/$repo_root_marker" ]]; do
    script_path=$(dirname "$script_path")
done

cd "$script_path/$repo_root_marker"

RULESET_DIR=$(pwd)/ruleset

# Load the integrations
cd $RULESET_DIR/integrations
engine-integration add -n system wazuh-core
engine-integration add -n wazuh apache-http
engine-integration add -n wazuh auditd
engine-integration add -n wazuh checkpoint
engine-integration add -n wazuh gcp
engine-integration add -n wazuh iis
engine-integration add -n wazuh microsoft-dhcp
engine-integration add -n wazuh microsoft-dnsserver
engine-integration add -n wazuh microsoft-exchange-server
engine-integration add -n wazuh modsecurity
engine-integration add -n wazuh pfsense
engine-integration add -n wazuh snort
engine-integration add -n wazuh squid
engine-integration add -n wazuh suricata
engine-integration add -n wazuh syslog
engine-integration add -n wazuh system
engine-integration add -n wazuh wazuh-dashboard
engine-integration add -n wazuh windows
engine-integration add -n wazuh zeek

# Load the rules
cd $RULESET_DIR/integrations-rules
engine-integration add -n wazuh auditd
engine-integration add -n wazuh sysmon-linux

# Load the filter (for the route)
cd $RULESET_DIR
engine-catalog -n system create filter < filters/allow-all.yml

# Create the default security policy
engine-policy create -p policy/wazuh/0
engine-policy parent-set decoder/integrations/0
engine-policy parent-set -n wazuh decoder/integrations/0

# Add the decoder integration to the security policy
engine-policy asset-add -n system integration/wazuh-core/0
engine-policy asset-add -n wazuh integration/apache-http/0
engine-policy asset-add -n wazuh integration/auditd/0
engine-policy asset-add -n wazuh integration/checkpoint/0
engine-policy asset-add -n wazuh integration/gcp/0
engine-policy asset-add -n wazuh integration/iis/0
engine-policy asset-add -n wazuh integration/microsoft-dhcp/0
engine-policy asset-add -n wazuh integration/microsoft-dnsserver/0
engine-policy asset-add -n wazuh integration/microsoft-exchange-server/0
engine-policy asset-add -n wazuh integration/modsecurity/0
engine-policy asset-add -n wazuh integration/pfsense/0
engine-policy asset-add -n wazuh integration/snort/0
engine-policy asset-add -n wazuh integration/squid/0
engine-policy asset-add -n wazuh integration/suricata/0
engine-policy asset-add -n wazuh integration/syslog/0
engine-policy asset-add -n wazuh integration/system/0
engine-policy asset-add -n wazuh integration/wazuh-dashboard/0
engine-policy asset-add -n wazuh integration/windows/0
engine-policy asset-add -n wazuh integration/zeek/0
# Add the rules (They are not necessary if you only want to develop decoders)
engine-policy asset-add -n wazuh integration/auditd-rules/0
engine-policy asset-add -n wazuh integration/sysmon-linux-rules/0
