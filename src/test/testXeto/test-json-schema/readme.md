# Overview

This is the external test suite for `xetom:: JsonSchemaExporter`.

This directory contains a python script which validates the JSON in
`instances.json` against the JSON Schema defined in `schema.json`.

Run `export-json` to re-create `instances.json`, and run `export-json-schema`
to re-create `schema.json`:

    cmd /c "fan xeto export-json                        hx.test.xeto > instances.json"
    cmd /c "fan xeto export-json-schema -outFormat json hx.test.xeto > schema.json"

Redirect through `cmd` on Windows.  PowerShell 5.1's `>` writes UTF-16 and its
`-Encoding utf8` adds a BOM; `schema-test.py` opens with the platform default
encoding and fails to parse either one.

Then run the python script to validate:

    python schema-test.py

