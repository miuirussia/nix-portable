#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3Packages.requests

import requests
import json
import re

def replace_nix_url_in_file(file_path, new_url):
    pattern = r'(\s+)nix\.url\s*=\s*"([^"]+)"\s*;'
    with open(file_path, 'r') as file:
        content = file.read()
    
    modified_content = re.sub(pattern, lambda match: f'{match.group(1)}nix.url = "{new_url}";', content)

    with open(file_path, 'w') as file:
        file.write(modified_content)

# Step 1: Get the ID of the latest jobset evaluation
url_id = 'https://hydra.nixos.org/job/nix/master/buildStatic.nix-everything.x86_64-linux/latest'
headers = {'Accept': 'application/json'}

response_id = requests.get(url_id, headers=headers)
response_id.raise_for_status()  # Check for HTTP request errors
data_id = response_id.json()
job_id = data_id['jobsetevals'][0]

# Step 2: Get the flake for the specific job ID
url_flake = f'https://hydra.nixos.org/jobset/nix/master/evals'
response_flake = requests.get(url_flake, headers=headers)
response_flake.raise_for_status()  # Check for HTTP request errors
data_flake = response_flake.json()

# Filter the evals to find the one with the specific job ID
for eval_entry in data_flake['evals']:
    if eval_entry['id'] == job_id:
        flake_result = eval_entry['flake']
        break

replace_nix_url_in_file('./flake.nix', flake_result)
