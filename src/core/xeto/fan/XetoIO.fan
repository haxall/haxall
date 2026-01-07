//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jan 2026  Brian Frank  Creation
//

using util

**
** XetoIO is used to read/write various Xeto formats via `Namespace.io`.
**
@Js
const mixin XetoIO
{

//////////////////////////////////////////////////////////////////////////
// Xeto
//////////////////////////////////////////////////////////////////////////

  **
  ** Read xeto instance data from Xeto source code.  Raise exception if there
  ** are any syntax or semantic errors.  If the input contains a scalar value
  ** or one dict, then it is returned as the value.  Or if the input contains
  ** two or more dicts then return a Dict[] of the instances.  The stream
  ** guaranteed to be closed upon return.
  **
  ** Options
  **   - externRefs: marker to allow unresolved refs to compile
  **
  abstract Obj? readXeto(InStream in, Dict? opts := null)

  **
  ** Convenience for `readXeto` but always returns data as list of dicts.
  ** If the data is not a Dict nor list of Dicts, then raise an exception.
  **
  abstract Dict[] readXetoDicts(InStream in, Dict? opts := null)

  **
  ** Write instance data to Xeto source code.  If the val is a Dict[], then
  ** it is flattened in the output.  The stream is left open and returned.
  **
  abstract OutStream writeXeto(OutStream out, Obj? val, Dict? opts := null)

//////////////////////////////////////////////////////////////////////////
// JSON
//////////////////////////////////////////////////////////////////////////

  **
  ** Read xeto instance data from JSON.  The given spec is used
  ** to infer the JSON object if no 'spec' tag is defined.
  ** The stream guaranteed to be closed upon return.
  **
  abstract Obj? readJson(InStream in, Spec? spec := null, Dict? opts := null)

  **
  ** Write xeto instance data as JSON
  ** The stream is left open and returned.
  **
  ** Options:
  **   - pretty: add indentation to pretty print
  **   - escUnicode: use escape sequences for values greater than 0x7f
  **
  abstract OutStream writeJson(OutStream out, Obj? val, Dict? opts := null)

//////////////////////////////////////////////////////////////////////////
// Binary
//////////////////////////////////////////////////////////////////////////

  **
  ** Read xeto data using internal binary format.
  ** The stream guaranteed to be closed upon return.
  **
  @NoDoc abstract Obj? readBinary(InStream in, Dict? opts := null)

  **
  ** Write xeto data using internal binary format.
  ** The stream is left open and returned.
  **
  @NoDoc abstract OutStream writeBinary(OutStream out, Obj? val, Dict? opts := null)
}

