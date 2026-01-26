This documentation describes the `JsonSchemaExporter` class, a Fantom-based
utility designed to translate **Xeto** specifications into **JSON Schema (Draft
07)**.

---

## Xeto JSON Schema Exporter

The `JsonSchemaExporter` is a specialized exporter that converts Xeto libraries
and specs into machine-readable JSON Schema files. This allows Xeto data models
to be used for validation in standard web environments, IDEs, and
cross-platform integrations.

### Key Features

* **Standard Compliance**: Generates schemas compatible with **JSON Schema
  Draft 07**.
* **Recursive Resolution**: Automatically discovers and defines all referenced
  types across namespaces.
* **Inheritance Support**: Uses the `allOf` keyword to mirror Xeto’s type
  inheritance, ensuring base type constraints are preserved.
* **Library Versioning**: Organizes definitions (`$defs`) by library name and
  version to prevent naming collisions.

---

### Mapping Logic

The exporter maps Xeto model primitives and structures to their JSON Schema equivalents as follows:

| Xeto Type / Feature | JSON Schema Representation | Notes |
| --- | --- | --- |
| **Scalar / Str** | `type: "string"` | Maps `pattern` facets to regex validation. |
| **Bool / Int / Float** | `boolean`, `integer`, `number` | Direct primitive mapping. |
| **Enum** | `type: "string"` + `enum` | Extracts all keys from the Xeto enum. |
| **List** | `type: "array"` | Sets `items` to a `$ref` of the list's member type. |
| **Dict / Obj** | `type: "object"` | Maps Xeto slots to `properties`. |
| **Optionality** | `required: [...]` | Slots marked as `maybe` are excluded from the required list. |
| **Inheritance** | `allOf: [ { $ref: base }, { ... } ]` | Implements Xeto type extension logic. |

---

### Architecture & Usage

#### Output Structure

The exporter generates a single JSON document where the primary definitions are
stored in a nested `$defs` object, keyed by the library identifier (e.g.,
`sys-1.0`).

#### Integration Example

The exporter implements the standard Xeto `Exporter` lifecycle:

1. **`lib(Lib)`**: Call this to export an entire library. It iterates through
   all specs and assigns the library documentation as the schema `title`.
2. **`spec(Spec)`**: Call this to export a specific type.
3. **`end()`**: Finalizes the JSON object and streams it to the standard output
   with pretty-printing enabled.

```fantom
// Example: Exporting a library to JSON Schema
exporter := JsonSchemaExporter(ns, Env.cur.out, [:])
exporter.lib(myXetoLib)
exporter.end()

```

---

### Technical Constraints

* **Compound Types**: Currently, Xeto compound types are not supported and will
  throw an error.
* **Additional Properties**: Generated objects set `additionalProperties: true`
  by default to remain compatible with Xeto's flexible dictionary nature.

