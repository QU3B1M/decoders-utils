#!/usr/bin/env python3
import yaml
import sys
import json
import traceback


class NoTagLoader(yaml.SafeLoader):
    pass


# Treat unknown tags as plain strings
NoTagLoader.add_constructor(
    None, lambda loader, node: loader.construct_scalar(node))


def handle_special_fields(processor):
    operation = get_operation(processor)
    if "field" in processor[operation]:
        if processor[operation]["field"] == "@timestamp":
            processor[operation]["field"] = "event.start"


def handle_parse(processor):
    operation = get_operation(processor)
    if operation == "grok":
        key = processor[operation]["field"]
        patterns = []
        # Replace %{PATTERN} with <PATTERN>
        for pattern in processor[operation].get("patterns", []):
            patterns.append(pattern.replace("%{", "<").replace("}", ">"))
        # Substitute pattern definitions if present
        definitions = processor[operation].get("pattern_definitions", {})
        if definitions:
            for def_key, def_value in definitions.items():
                def_value = def_value.replace("%{", "<").replace("}", ">")
                patterns = [p.replace(def_key, def_value) for p in patterns]
        return {f"parse|{key}": patterns} if patterns else None

    if operation == "dissect":
        key = processor[operation]["field"]
        pattern = processor[operation].get("pattern", "")
        if pattern:
            pattern = pattern.replace("%{", "<").replace("}", ">")
            return {f"parse|{key}": [pattern]}
        return None

    return None


def handle_check(processor):
    operation = get_operation(processor)
    if operation == "dissect" or operation == "grok":
        key = processor[operation]["field"]
        return {"check": f"exists(${key})"}
    if "if" not in processor[operation].keys():
        return None
    conditional_block = processor[operation]["if"]
    conditional_block = conditional_block.replace("ctx.", "").replace("ctx?.", "").replace(
        "?", "").replace("&&", "AND").replace("||", "OR")
    if ".contains(" in conditional_block:
        # Handle contains logic
        parts = conditional_block.split(".contains(")
        field = parts[0].strip()
        value = parts[1].rstrip(")").strip()
        return {"check": f"contains(${field}, {value})"}
    elif "==" in conditional_block:
        parts = conditional_block.split("==")
        field = parts[0].strip()
        value = parts[1].strip()
        return {"check": f"${field} == {value}"}
    else:
        return {"check": conditional_block}
    return None


def get_operation(processor):
    operation = list(processor.keys())[0]
    return operation


def elastic_to_strftime(fmt: str) -> str:
    mapping = {
        "yyyy": "%Y",   # 4-digit year
        "yy": "%y",     # 2-digit year
        "MMMM": "%B",   # full month name
        "MMM": "%b",    # abbreviated month name
        "MM": "%m",     # zero-padded month number
        "M": "%-m",     # month number (no padding, Linux/macOS)
        "dd": "%d",     # zero-padded day
        "d": "%-d",     # day (no padding)
        "HH": "%H",     # 24-hour
        "hh": "%I",     # 12-hour
        "mm": "%M",     # minutes
        "ss": "%S",     # seconds
        "a": "%p",      # AM/PM
        "EEE": "%a",    # abbreviated weekday
        "EEEE": "%A",   # full weekday
    }

    # Sort by length to replace longer patterns first
    for k in sorted(mapping.keys(), key=len, reverse=True):
        fmt = fmt.replace(k, mapping[k])
    return fmt


def dispatch(processor):
    operation = get_operation(processor)
    handlers = {
        "append": handle_append,
        "convert": handle_convert,
        "csv": handle_csv,
        "date": handle_date,
        "fingerprint": handle_fingerprint,
        "foreach": handle_foreach,
        "geoip": handle_geoip,
        "gsub": handle_gsub,
        "json": handle_json,
        "kv": handle_kv,
        "lowercase": handle_lowercase,
        "pipeline": handle_pipeline,
        "remove": handle_remove,
        "rename": handle_rename,
        "script": handle_script,
        "set": handle_set,
        "split": handle_split,
        "trim": handle_trim,
        "uppercase": handle_uppercase,
        "urldecode": handle_urldecode,
        "uri_parts": handle_urldecode,
        "user_agent": handle_user_agent,
        # "dissect" is intentionally skipped
    }
    if operation == "dissect" or operation == "grok":
        # Skipping dissect and grok as they are handled as special cases
        return None
    if operation in handlers:
        return handlers[operation](processor[operation])
    else:
        raise ValueError(f"Unknown processor type: {operation}")


def build_normalize(processors):
    try:
        normalize_list = []
        map_block = []
        for index, processor in enumerate(processors):
            handle_special_fields(processor)
            map_item = dispatch(processor)
            operation = get_operation(processor)
            check = handle_check(processor)
            parse = handle_parse(processor)
            normalize_length = len(normalize_list)
            if check:
                normalize_block = {}
                map_block = []
                normalize_block.update(check)
                if parse:
                    normalize_block.update(parse)
                    normalize_list.append(normalize_block)
                    continue
                normalize_block.update({"map": map_block})
                normalize_list.append(normalize_block)
            elif index == 0 or "check" in normalize_list[normalize_length - 1].keys():
                normalize_block = {}
                map_block = []
                normalize_block.update({"map": map_block})
                normalize_list.append(normalize_block)

            if isinstance(map_item, list):
                for i in map_item:
                    map_block.append(i)
            else:
                map_block.append(map_item)
    except Exception as e:
        traceback.print_exc()
        print(f"{e}\nException processing operation: {operation}")
        print(json.dumps(processor, indent=2))
        exit(1)
    return normalize_list


def handle_append(processor):
    # Handle 'append' processor logic
    key = processor["field"]
    values = processor["value"]
    if isinstance(values, str):
        values = [values]
    helper_function = "array_append"
    statements = []
    for value in values:
        if value.startswith("{{{"):
            value = value.replace("{", "").replace("}", "")
            value = f"${value}"
        statements.append({key: f"{helper_function}({value})"})
    return statements


def handle_convert(processor):
    # Handle 'convert' processor logic
    if "target_field" in processor:
        key = processor["target_field"]
    else:
        key = f"{processor['field']}"
    value = processor["field"]
    helper_function = f"parse_{processor['type']}"

    return {key: f"{helper_function}(${value})"}

def handle_csv(processor):
    # Handle 'csv' processor logic
    key = processor["field"]
    helper_function = f"parse_csv"
    target_fields = processor.get("target_fields", [])


    return {key: f"{helper_function}(${key}, {','.join(target_fields)})"}


def handle_date(processor):
    # Handle 'date' processor logic
    if processor.get("target_field"):
        key = processor["target_field"]
    else:
        key = processor['field']
    value = f"${processor['field']}"
    helper_function = "parse_date"
    if "formats" in processor:
        return [{key: f"{helper_function}({value}, {elastic_to_strftime(format_string)},en_US.UTF-8)"} for format_string in processor["formats"]]
    return {key: f"{helper_function}({value},ISO8601,en_US.UTF-8)"}


def handle_fingerprint(processor):
    # Handle 'fingerprint' processor logic
    key = processor["target_field"]
    fields = processor.get("fields", [])
    if len(fields) < 2:
        value = f"${fields[0]}"
        helper_function = "sha1"
        return {key: f"{helper_function}({value})"}

    tmp_field = "_to_hash"
    # Concatenate all fields into a temporary field
    concat_fields = ",".join([f"${f}" for f in fields])
    concat_statement = {tmp_field: f"concat_any({concat_fields})"}
    # Hash the concatenated value
    hash_statement = {key: f"sha1(${tmp_field})"}
    # Remove the temporary field
    delete_statement = {tmp_field: "delete()"}
    return [concat_statement, hash_statement, delete_statement]


def handle_foreach(processor):
    sub_processor = processor["processor"]
    return dispatch(sub_processor)


def handle_geoip(processor):
    # Handle 'geoip' processor logic
    key = processor["target_field"]
    value = f"${processor['field']}"

    if key.endswith("geo"):
        helper_function = "geoip"
    else:
        helper_function = "as"

    return {key: f"{helper_function}({value})"}


def handle_gsub(processor):
    # Handle 'gsub' processor logic
    key = processor["field"]
    value = f"\"{processor['pattern']}\",\"{processor['replacement']}\""
    helper_function = "replace"

    return {key: f"{helper_function}({value})"}


def handle_json(processor):
    # Handle 'json' processor logic
    key = processor["target_field"]
    value = processor["field"]
    helper_function = "parse_json"

    return {key: f"{helper_function}(${value})"}


def handle_kv(processor):
    # Handle 'kv' processor logic
    key = processor["target_field"]
    value = processor["field"]
    separator = f"\'{processor['value_split']}\'"
    delimiter = f"\'{processor['field_split']}\'"
    quote = "\'\"\'"
    escape = "\'\\\\\'"
    helper_function = "parse_key_value"
    return {key: f"{helper_function}(${value}, {separator}, {delimiter}, {quote}, {escape})"}


def handle_lowercase(processor):
    # Handle 'lowercase' processor logic
    key = processor["field"]
    value = f"${key}"
    helper_function = "downcase"
    return {key: f"{helper_function}({value})"}


def handle_pipeline(processor):
    # Handle 'pipeline' processor logic
    return processor["name"]


def handle_remove(processor):
    # Handle 'remove' processor logic
    key = processor["field"]
    helper_function = "delete"

    if not isinstance(key, list):
        return {key: f"{helper_function}()"}

    statements = []
    for item in key:
        statements.append({item: f"{helper_function}()"})

    return statements


def handle_rename(processor):
    # Handle 'rename' processor logic
    return {processor["target_field"]: f"rename(${processor['field']})"}


def handle_script(processor):
    # Handle 'script' processor logic
    key = "THIS_IS_A_SCRIPT"
    value = " ".join(processor["source"].replace(
        "\n", " ").replace("\r", "").splitlines())
    helper_function = "LOOK AT THE PIPELINE"
    return {key: f"{helper_function}({value})"}


def handle_set(processor):
    # Handle 'set' processor logic
    if "copy_from" in processor:
        return {processor["field"]: f"${processor['copy_from']}"}
    elif "value" in processor:
        return {processor["field"]: f"{processor['value']}"}
    return None


def handle_split(processor):
    key = processor["field"]
    value = f"${processor['field']}"
    separator = f"'{processor['separator']}'"
    helper_function = "split"
    # Replace the separator string with a single character
    replace_statement = {key: f"replace({separator}, '|')"}
    split_statement = {key: f"{helper_function}({value},'|')"}
    return [replace_statement, split_statement]


def handle_trim(processor):
    key = processor["field"]
    value = f"${key}"
    helper_function = "trim"
    return {key: f"{helper_function}({value}, 'both', ' ')"}


def handle_uppercase(processor):
    key = processor["field"]
    value = f"${key}"
    helper_function = "upcase"
    return {key: f"{helper_function}({value})"}


def handle_urldecode(processor):
    # Handle 'urldecode' processor logic
    key = processor["field"]
    value = f"${processor['field']}"
    helper_function = "parse_uri"
    return {key: f"{helper_function}({value})"}


def handle_user_agent(processor):
    # Handle 'user_agent' processor logic
    key = processor["field"]
    value = f"${key}"
    helper_function = "parse_useragent"
    return {key: f"{helper_function}({value})"}


def main():
    if len(sys.argv) < 2:
        print("Usage: python read_pipeline.py <yaml_file>")
        sys.exit(1)

    file_path = sys.argv[1]

    try:
        with open(file_path, "r") as f:
            yaml_data = yaml.load(f, Loader=NoTagLoader)
        result = {"normalize": build_normalize(yaml_data["processors"])}
        print(yaml.dump(result))

    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.")
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}")


if __name__ == "__main__":
    main()
