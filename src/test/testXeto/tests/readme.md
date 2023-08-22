# Overview

The Xeto test suite is provided as a directory of YAML files.
Each file tests one major feature of the infrastructure.  A test
file contains one or more test cases as YAML documents.

# Test Case

Each test case is a YAML document.  A test case must specify a `name`
field which uniquely defines the test within its YAML file.  Names
are used to run and report test cases.

The remainder of the test case fields define a step within the test.
The field name identifies the step type, and the value is the argument
to the step.  Steps come in two flavors: setup and verifies.  Setup
performs some action such as compiling Xeto source code into a library.
Verifies are used to verify the setup steps.

The following are the step types discussed in further detail below:
  - **loadLib**: load a predefined library by name
  - **compileLib**: compile a library from source code
  - **compileData**: compile data from from source code
  - **verifyType**: verify a type from the active library
  - **verifyTypes**: convenience to verify a list of types
  - **verifyData**: verify the data value from compileData
  - **verifySpecIs**: verify nonimal typing between two specs
  - **verifySpecFits**: verify structural typing between two specs
  - **verifyErrs**: verify compile time errors

Any test that uses a qname from `compileLib` can assume the library
is called "test" (but in reality it is likely something like "temp123").

# Test Steps

## loadLib

Load a library by name.  This library becomes the active library for
use with steps such as `verifyType`.

Examples:

    loadLib: "sys"

## compileLib

Compile a library from source.  This library becomes the active library for
use with steps such as `verifyType`.
Examples:

    compileLib: |
      Foo: Dict { someMarker }
      Bar: Foo

## compileData

Compile a data value from source.  This value becomes the active data for
use with steps such as `verifyData`.

    compileData: |
      Date "2023-03-05"

## verifyType

Verify a type by name from the active library (see `loadLib` and `compileLib`).
The value is a map with the following fields:

  - **name**: simple name of the type within the library
  - **base**: qname of the base spec
  - **meta**: map of the effective meta formatted as `verifyData`
  - **slots** map of the effective slots

The slot map is the expected slot spec which follows the same rules
as `verifyType` with the exception that `base` is replaced with `type`.

## verifyTypes

This is a convenience for verifying a list of types in the active library
using a map of type names.  It follows the exact same conditions as `verifyType`
with the exception that `name` is omitted.

## verifyData

Verify a data value.

Scalars are verified using the syntax "type value".  If the type is marker
then the value is omitted:

    "sys::Str hello world"
    "sys::Marker"
    "sys::Number 123"

Dicts are verified as a map where the keys specify the expected value type.
Plus each Dict value should have a 'spec' field with the qname of the dict's
type:

    spec: "sys::Dict"
    str: "sys::Str hello world"
    marker: "sys::Marker"

## verifySpecIs

Verify nonimal typing via two specs.  This field must be a list of
dicts with the following three fields:
  - **a**: qname of spec
  - **b**: qname of spec
  - **expect**: expected value  of `is(a, b)`

Example:

    verifySpecIs:
      - {a: "sys::Str", b: "sys::Scalar", expect: true}
      - {a: "sys::Str", b: "sys::Number", expect: false}

## verifySpecFits

Verify structural typing between two specs.  This step follows the
exact same conventions as `verifySpecIs`.

## verifyErrs

Verify compiler errors for Xeto source code with illegal syntax/semantics.
The value is a multiline string with an expected error on each line.

