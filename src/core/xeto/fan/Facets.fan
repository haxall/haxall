//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

**
** Api facet is applied to Fantom methods to expose them as xeto funcs
**
@Js facet class Api {}

**
** Gen facet marks a type or slot as generated from xeto specs
** by the 'xeto gen-fan' command line tool.  The type level facet
** opts a class into generation and the slot level facet marks each
** machine-owned slot: generation updates them in place, inserts
** slots missing from the spec, and removes slots no longer declared
** by the spec.
**
@Js facet class Gen
{
  ** Customization hooks for code generation encoded as a xeto dict
  ** string without the enclosing braces such as "skip:\"foo,bar\", funcs".
  ** Pairs may be separated by commas or newlines.  The tag vocabulary
  ** is defined by the generation tool.
  const Str? meta
}

