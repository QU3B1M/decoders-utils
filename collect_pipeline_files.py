import argparse
import requests
from pathlib import Path
import sys

GITHUB_REPO = "elastic/integrations"
BASE_URL = f"https://api.github.com/repos/{GITHUB_REPO}/contents"
RAW_BASE_URL = "https://raw.githubusercontent.com/elastic/integrations/main"

def fetch_file_list(integration_name):
    path = f"packages/{integration_name}/data_stream/log/_dev/test/pipeline"
    url = f"{BASE_URL}/{path}"
    response = requests.get(url)
    response.raise_for_status()
    return response.json()

def download_and_merge_files(file_list, extension_filter, output_file):
    with open(output_file, 'w', encoding='utf-8') as outfile:
        for file_info in file_list:
            filename = file_info['name']
            if filename.endswith(extension_filter):
                raw_url = f"{RAW_BASE_URL}/{file_info['path']}"
                print(f"Downloading: {raw_url}")
                file_response = requests.get(raw_url)
                file_response.raise_for_status()
                outfile.write(file_response.text)
                outfile.write('\n')

def main():
    parser = argparse.ArgumentParser(
        description="Merge .log and *-expected.json files from Elastic Integrations repo"
    )
    parser.add_argument(
        "integration_name",
        help="Name of the integration (e.g., apache, nginx, cisco_ios, etc.)"
    )

    args = parser.parse_args()
    integration_name = args.integration_name

    try:
        file_list = fetch_file_list(integration_name)
    except requests.HTTPError as e:
        print(f"Error fetching file list: {e}")
        sys.exit(1)

    download_and_merge_files(file_list, ".log", "combined_logs.log")
    download_and_merge_files(file_list, "-expected.json", "combined_expected.json")

if __name__ == "__main__":
    main()
