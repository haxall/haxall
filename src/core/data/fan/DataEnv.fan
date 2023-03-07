//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using util

**
** Environment for the data processing subsystem.
** There is one instance for the VM accessed via `DataEnv.cur`.
**
@Js
const abstract class DataEnv
{
  ** Current default environment for the VM
  static DataEnv cur() { curRef ?: throw Err("DataEnv not initialized") }

  // init env instance using reflection
  private static const DataEnv? curRef
  static
  {
    try
    {
      curRef = Type.find("xeto::XetoEnv").make
    }
    catch (Err e)
    {
      echo("ERROR: cannot init DataEnv.cur")
      e.trace
    }
  }

  ** Marker singleton
  abstract Obj marker()

  ** Empty dict singleton
  abstract DataDict emptyDict()

  ** Return generic 'sys::Dict'
  @NoDoc abstract DataSpec dictSpec()

  ** Data type for Fantom object
  abstract DataType? typeOf(Obj? val, Bool checked := true)

  ** Create Dict from given value:
  **   - If null, return empty dict
  **   - If DataDict, return it
  **   - If Fantom Map, wrap as DataDict
  **   - Raise exception for any other value type
  abstract DataDict dict(Obj? val, DataSpec? spec := null)

  ** List the library qnames installed by this environment
  abstract Str[] libsInstalled()

  ** Return if given library is loaded into memory
  abstract Bool isLibLoaded(Str qname)

  ** Get or load library by the given qualified name
  abstract DataLib? lib(Str qname, Bool checked := true)

  ** Compile Xeto source code into a temp library
  abstract DataLib compileLib(Str src)

  ** Compile Xeto data file into in-memory dict/scalar tree
  abstract Obj? compileData(Str src)

  ** Get or load type by the given qualified name
  abstract DataType? type(Str qname, Bool checked := true)

  ** Pretty print object to output stream.
  abstract Void print(Obj? val, OutStream out := Env.cur.out, Obj? opts := null)

  ** Debug dump of environment
  @NoDoc abstract Void dump(OutStream out := Env.cur.out)

}