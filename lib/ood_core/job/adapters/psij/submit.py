import sys
from psij import Job, JobExecutor
from psij.serialize import JSONSerializer
from pathlib import Path
import json
import os

# create executor instance.
ex = JobExecutor.get_instance(sys.argv[1])

# deserialize json data to job spec.
deserialize = JSONSerializer()
d = sys.stdin.read()
j = json.loads(d)
spec = deserialize._to_spec(j)

# add executor string to each key of custom attributes.
if sys.argv[1] != "local" and spec.attributes.custom_attributes is not None:
    h = {}
    for k in spec.attributes.custom_attributes.keys():
        h[f"{ex.name}.{k}"] = spec.attributes.custom_attributes[k]
    spec.attributes.custom_attributes = h

spec.executable = os.path.expanduser(spec.executable)
job = Job(spec)

ex.submit(job)
print(job.native_id)
