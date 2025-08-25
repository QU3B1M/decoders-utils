#!/usr/bin/env python3
import json
import sys

def add_indices_to_json(file_path):
    """Add _index property to each object in a JSON array."""
    try:
        # Read the JSON file
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Check if it's a list
        if not isinstance(data, list):
            print("Error: JSON file must contain an array of objects")
            return False
        
        # Add _index property to each object
        for i, obj in enumerate(data):
            if isinstance(obj, dict):
                obj['_index'] = i
            else:
                print(f"Warning: Item at position {i} is not an object")
        
        # Write back to file with proper formatting
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        
        print(f"Successfully added indices to {len(data)} objects")
        return True
        
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python add_indices.py <json_file>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    success = add_indices_to_json(file_path)
    sys.exit(0 if success else 1)
