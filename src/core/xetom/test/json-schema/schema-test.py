#
# One time setup:
#   pip install jsonschema
#

import json
from jsonschema import validate, ValidationError

# Open the file and load the data
with (
    open('schema.json', 'r') as schema_file,
    open('instances.json', 'r') as instances_file
):

  schema = json.load(schema_file)
  instances = json.load(instances_file)

  try:
    validate(instance=instances, schema=schema)
    print("JSON is valid!")
  except ValidationError as e:
    print(f"Validation failed: {e.message}")
