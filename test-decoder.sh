#!/bin/bash

INTEGRATION_NAME="$1"
INTEGRATION_DIR="../intelligence-data/ruleset/integrations/${INTEGRATION_NAME}"
TEST_DIR="${INTEGRATION_DIR}/test"
OLDIFS=$IFS
IFS=$'\n'

# Find all *_input.txt files in the test directory
input_files=($(find "$TEST_DIR" -name "*_input.txt" -type f))

if [[ ${#input_files[@]} -eq 0 ]]; then
    echo "No *_input.txt files found in: $TEST_DIR"
    exit 1
fi

echo "Found ${#input_files[@]} input file(s):"
for file in "${input_files[@]}"; do
    echo "  $(basename "$file")"
done

for f in "${input_files[@]}"; do
    echo "Running tests for integration: $INTEGRATION_NAME"
    for i in $(cat "${f}")
        do echo $i | engine-test -c "${TEST_DIR}/engine-test.conf" run "$INTEGRATION_NAME"
        echo ""
        echo ""
        echo ""
        echo "$i"
        echo ""
        echo ""
        echo ""
        read -p "Press enter to continue"
    done
done
IFS=$OLDIFS