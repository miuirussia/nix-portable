import requests
import json

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

# Print the flake
print(flake_result)

