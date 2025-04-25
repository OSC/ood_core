import argparse
import json
from datetime import datetime, timedelta
import time

parser = argparse.ArgumentParser(description="Process job parameters")
parser.add_argument("--id", type=str, help="Path to the job script")
parser.add_argument("--owner", type=str, help="the name of job owner")
parser.add_argument("--executor", type=str, required=True, help="Executor to be used")

args = parser.parse_args()

from psij import Job, JobExecutor
from psij.serialize import JSONSerializer

ex = JobExecutor.get_instance(args.executor)
if args.id:
    job = Job()
    job._native_id = args.id
    job_data = ex.info([job])
elif args.owner:
    job_data = ex.info(owner=args.owner)
else:
    job_data = ex.info()

s = JSONSerializer()
# create dict for each job.
# [ {'native_id': native_id, ... }, {'native_id': native_id, ...}, ...]
data = []
for job in job_data:
    d = {}
    d["native_id"] = job.native_id
    d["current_state"] = job._status.state.name
    d.update(job.current_info.__dict__)
    d.update(s._from_spec(job.spec))
    # the attributes and resources are nested in the job data.
    # we need to flatten them.
    attr = d["attributes"]
    del d["attributes"]
    # convert deltatime or string to integer
    d["duration"] = job.spec.attributes.duration.total_seconds()
    d["wall_time"] = int(d["wall_time"])
    d.update(attr)
    resources = d["resources"]
    del d["resources"]
    d.update(resources)
    d["submission_time"] = d["submission_time"].strftime("%Y-%m-%d %H:%M:%S")
    d["dispatch_time"] = d["dispatch_time"].strftime("%Y-%m-%d %H:%M:%S")

    data.append(d)

print(json.dumps(data))
