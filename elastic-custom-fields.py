#!/usr/bin/env python3

# Prints a list of custom fields
# out of an elastic pipeline's fields.yml file
# in csv format

import sys
import yaml


#def flatten(fields, prefix=""):
#    result = {}
#    for field in fields:
#        name = f"{prefix}.{field['name']}" if prefix else field['name']
#        if field.get("type") == "group" and "fields" in field:
#            result.update(flatten(field["fields"], name))
#        else:
#            result[name] = field["type"]
#    return result

def flatten(fields, prefix=""):
    result = {}
    for field in fields:
        if not isinstance(field, dict):  # safety check
            continue
        name = f"{prefix}.{field.get('name')}" if prefix else field.get("name")
        ftype = field.get("type")
        if ftype == "group" and "fields" in field:
            result.update(flatten(field["fields"], name))
        elif ftype:
            result[name] = ftype
    return result

def main():
    if len(sys.argv) < 2:
        print("Usage: python elastic-custom-fields.py <yaml_file>")
        sys.exit(1)

    file_path = sys.argv[1]

    try:
        with open(file_path, "r") as f:
            yaml_data = yaml.safe_load(f)
        flattened = flatten(yaml_data)
        for key in flattened:
            print(f"{key},{flattened.get(key, None)}")

    except Exception as e:
        print(f"Error parsing YAML: {e}")


if __name__ == "__main__":
    main()
