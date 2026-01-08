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
  ** two or more dicts then return a Dict[] of the instances.
  **
  ** Options
  **   - externRefs: marker to allow unresolved refs to compile
  **
  abstract Obj? readXeto(Str in, Dict? opts := null)

  **
  ** Convenience for `readXeto` but always returns data as list of dicts.
  ** If the data is not a Dict nor list of Dicts, then raise an exception.
  **
  abstract Dict[] readXetoDicts(Str in, Dict? opts := null)

  **
  ** Write instance data to Xeto source code.  If the val is a Dict[], then
  ** it is flattened in the output.  The stream is left open and returned.
  **
  abstract OutStream writeXeto(OutStream out, Obj? val, Dict? opts := null)

  **
  ** Convenience for writeXeto to an in-memory string
  **
  abstract Str writeXetoToStr(Obj? val, Dict? opts := null)

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

  **
  ** Convenience for writeJson to an in-memory string
  **
  abstract Str writeJsonToStr(Obj? val, Dict? opts := null)

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////

  **
  ** Parse the Xeto source representation into its dict AST representation.
  **
  ** Options:
  **   - libName: for internal qnames (default to proj)
  **   - rtInclude: marker to make it a Haxall rt rec
  **
  abstract Dict readAst(Str in, Dict? opts := null)

  **
  ** Print the Xeto source representation from its dict AST representation.
  ** The stream is left open and returned.
  **
  abstract OutStream writeAst(OutStream out, Dict ast, Dict? opts := null)

  **
  ** Convenience for writeAst to an in-memory string
  **
  abstract Str writeAstToStr(Dict ast, Dict? opts := null)

  **
  ** Parse the Axon source representation into its dict AST representation.
  ** Return dict with following tags that are extracted from axon source:
  **   - doc: str for leading comment
  **   - slots: grid for parameters and return type
  **   - axon: source code for everything after "=>"
  **
  ** Options:
  **   - libName: for internal qnames (default to proj)
  **
  abstract Dict readAxon(Str in, Dict? opts := null)

  **
  ** Print the Axon source representation from its dict AST representation.
  ** The stream is left open and returned.
  **
  abstract OutStream writeAxon(OutStream out, Dict ast, Dict? opts := null)

  **
  ** Convenience for writeAxon to an in-memory string
  **
  abstract Str writeAxonToStr(Dict ast, Dict? opts := null)

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

//////////////////////////////////////////////////////////////////////////
// Print
//////////////////////////////////////////////////////////////////////////

  ** Pretty print any object to output stream.
  @NoDoc abstract Void print(Obj? val, OutStream out := Env.cur.out, Dict? opts := null)

}

