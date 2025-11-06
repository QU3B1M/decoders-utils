import json
import sys
import csv
from pathlib import Path

# Map Python types to OpenSearch data types
TYPE_MAP = {
    "str": "keyword",
    "int": "long",
    "float": "float",
    "bool": "boolean",
    "dict": "object",
    "list": "nested",
    "NoneType": "null"
}


def to_opensearch_type(value):
    py_type = type(value).__name__
    return TYPE_MAP.get(py_type, "unknown")


def load_ecs_fields(csv_path):
    """Load ECS fields from CSV file and return a set of field names."""
    ecs_fields = set()
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        fieldname = None
        # Try to detect column containing the field names
        for name in reader.fieldnames:
            if name.lower() in ("field", "name", "field.name"):
                fieldname = name
                break
        if not fieldname:
            # Fall back to first column if unknown header
            fieldname = reader.fieldnames[0]
        for row in reader:
            field = row[fieldname].strip()
            if field:
                ecs_fields.add(field)
    return ecs_fields


def describe_types(obj, ecs_fields, path=""):
    """Recursively print fields in YAML-style OpenSearch mapping format, skipping ECS fields."""
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in ["agent", "@timestamp", "wazuh"]:
                continue  # Skip known non-relevant fields
            full_path = f"{path}.{key}" if path else key
            if full_path in ecs_fields:
                continue  # Skip ECS field
            os_type = to_opensearch_type(value)
            print(f"- field: {full_path}")
            print(f"  type: {os_type}")
            print(f"  description: |")
            print(f"    <COPILOT, REPLACE THIS WITH A 5 WORD+ DESCRIPTION OF THE FIELD NAME ENDING WITH A DOT.>\n")
            describe_types(value, ecs_fields, full_path)
    elif isinstance(obj, list):
        # Assume all elements in the list share the same structure
        if obj:
            first = obj[0]
            describe_types(first, ecs_fields, path)


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {Path(sys.argv[0]).name} <json_file> <ecs_csv>")
        sys.exit(1)

    json_path = Path(sys.argv[1])
    ecs_csv_path = Path(sys.argv[2])

    if not json_path.exists():
        print(f"Error: JSON file '{json_path}' not found.")
        sys.exit(1)
    if not ecs_csv_path.exists():
        print(f"Error: ECS CSV file '{ecs_csv_path}' not found.")
        sys.exit(1)

    with open(json_path, "r") as f:
        data = json.load(f)

    # Handle case where root is an array
    if isinstance(data, list) and data:
        data = data[0]

    ecs_fields = load_ecs_fields(ecs_csv_path)
    describe_types(data, ecs_fields)


if __name__ == "__main__":
    main()
