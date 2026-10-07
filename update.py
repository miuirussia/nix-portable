#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3Packages.requests

import re
from pathlib import Path

import requests


HYDRA_URL = "https://hydra.nixos.org"
HEADERS = {"Accept": "application/json"}
REQUEST_TIMEOUT = 30


def get_json(url):
    response = requests.get(url, headers=HEADERS, timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.json()


def replace_nix_url_in_file(file_path, new_url):
    pattern = r'(\s+)nix\.url\s*=\s*"([^"]+)"\s*;'
    path = Path(file_path)
    content = path.read_text()

    modified_content, replacements = re.subn(
        pattern, lambda match: f'{match.group(1)}nix.url = "{new_url}";', content
    )
    if replacements != 1:
        raise RuntimeError(f"expected one nix.url entry in {path}, found {replacements}")

    path.write_text(modified_content)


# Step 1: Get the ID of the latest jobset evaluation
url_id = f"{HYDRA_URL}/job/nix/master/buildStatic.nix-everything.x86_64-linux/latest"
data_id = get_json(url_id)

jobset_evals = data_id.get("jobsetevals", [])
if not jobset_evals:
    raise RuntimeError("Hydra response did not include a jobset evaluation ID")

jobset_eval_id = jobset_evals[0]

# Step 2: Query that evaluation directly. The jobset evaluations list is paginated,
# so the matching evaluation might not appear on its first page.
evaluation = get_json(f"{HYDRA_URL}/eval/{jobset_eval_id}")
flake_result = evaluation.get("flake")
if not isinstance(flake_result, str) or not flake_result:
    raise RuntimeError(f"Hydra evaluation {jobset_eval_id} did not include a flake URL")

replace_nix_url_in_file("./flake.nix", flake_result)
