# Overview

This is the external test suite for `xetom:: JsonSchemaExporter`.

This directory contains a python script which validates the JSON in 
`instances.xeto` against the JSON Schema defined in `schema.json`.

Run `export-json` to re-create `instances.json`, and run `export-json-schema`
to re-create `schema.json`:

    fan xeto export-json hx.test.xeto.schema > instances.json
    fan xeto export-json-schema hx.test.xeto.schema > schema.json

Then run the python script to validate:

    python .\schema-test.py

