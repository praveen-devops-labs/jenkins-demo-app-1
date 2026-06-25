import sys
import uuid
import yaml

file = sys.argv[1]
app = sys.argv[2]
repo = sys.argv[3]
branch = sys.argv[4]
env = sys.argv[5]
actions = sys.argv[6].split(",")
user = sys.argv[7]

with open(file) as f:
    data = yaml.safe_load(f) or {}

if "requests" not in data:
    data["requests"] = []

data["requests"].append({

    "id": str(uuid.uuid4()),

    "app": app,

    "repo": repo,

    "branch": branch,

    "env": env,

    "actions": actions,

    "commit": "",

    "requested_by": user,

    "status": "pending"

})

with open(file, "w") as f:
    yaml.safe_dump(
        data,
        f,
        sort_keys=False
    )
