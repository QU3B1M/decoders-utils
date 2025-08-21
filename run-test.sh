#!/bin/bash

set -ex
###
### Static tests
###
engine-health-test static -r ./ruleset metadata_validate
engine-health-test static -r ./ruleset schema_validate
engine-health-test static -r ./ruleset mandatory_mapping_validate
engine-health-test static -r ./ruleset event_processing_validate
engine-health-test static -r ./ruleset non_modifiable_fields_validate
engine-health-test static -r ./ruleset custom_field_documentation_validate
###
### Dynamic tests
###

ENGINE_DIR=/root/wazuh/src/engine
HT_ENV=/tmp/ht-env
HT_INIT=/tmp/ht-init
[ -d $HT_ENV ] && rm -rf $HT_ENV
[ -d $HT_INIT ] && rm -rf $HT_INIT

python3 ${ENGINE_DIR}/test/setupEnvironment.py -e $HT_ENV
engine-health-test dynamic -e $HT_ENV init -t ${ENGINE_DIR}/test/health_test/ -r ./ruleset
engine-health-test dynamic -e $HT_ENV assets_validate
engine-health-test dynamic -e $HT_ENV load_decoders
engine-health-test dynamic -e $HT_ENV validate_successful_assets --target decoder --skip wazuh-core
engine-health-test dynamic -e $HT_ENV validate_event_indexing --target decoder --skip wazuh-core
engine-health-test dynamic -e $HT_ENV validate_custom_field_indexing --target decoder
engine-health-test dynamic -e $HT_ENV run --target decoder --skip wazuh-core
engine-health-test dynamic -e $HT_ENV coverage_validate --target decoder --skip wazuh-core --output_file $HT_ENV/decoder_coverage_report.txt
engine-health-test dynamic -e $HT_ENV load_rules
engine-health-test dynamic -e $HT_ENV validate_successful_assets --target rule --skip wazuh-core
engine-health-test dynamic -e $HT_ENV validate_event_indexing --target rule --skip wazuh-core
engine-health-test dynamic -e $HT_ENV validate_custom_field_indexing --target rule
engine-health-test dynamic -e $HT_ENV run --target rule --skip wazuh-core
###
### path: $HT_ENV/logs/engine.log
###

exit 0
