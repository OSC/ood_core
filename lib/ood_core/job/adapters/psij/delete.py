import argparse

parser = argparse.ArgumentParser(description="Process job parameters")
parser.add_argument("--id", type=str, required=True, help="Path to the job script")
parser.add_argument("--executor", type=str, required=True, help="Executor to be used")

args = parser.parse_args()

from psij import Job, JobExecutor

ex = JobExecutor.get_instance(args.executor)
job = Job()
job._native_id = args.id
# catch exception
try:
  ex.cancel(job)
except Exception as e:
  print(f"Invalid job id specified")