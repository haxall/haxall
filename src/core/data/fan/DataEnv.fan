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
      if (Env.cur.runtime == "java")
      {
        echo("ERROR: cannot init DataEnv.cur")
        e.trace
      }
    }
  }

  ** Marker singleton
  abstract Obj marker()

  ** Return generic 'sys::Dict'
  @NoDoc abstract DataSpec dictSpec()

  ** Empty dict singleton
  @NoDoc abstract DataDict dict0()

  ** Create a Dict with one name/value pair
  @NoDoc abstract DataDict dict1(Str n, Obj v)

  ** Create a Dict with two name/value pairs
  @NoDoc abstract DataDict dict2(Str n0, Obj v0, Str n1, Obj v1)

  ** Create a Dict with three name/value pairs
  @NoDoc abstract DataDict dict3(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2)

  ** Create a Dict with four name/value pairs
  @NoDoc abstract DataDict dict4(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3)

  ** Create a Dict with five name/value pairs
  @NoDoc abstract DataDict dict5(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4)

  ** Create a Dict with six name/value pairs
  @NoDoc abstract DataDict dict6(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4, Str n5, Obj v5)

  ** Create a Dict from a map name/value pairs.
  @NoDoc abstract DataDict dictMap(Str:Obj map, DataSpec? spec := null)

  ** Coerce one of the following values to a dict:
  **   - null return empty dict
  **   - if DataDict return it
  **   - if Str:Obj wrap it as dict
  **   - raise exception for anything else
  abstract DataDict dict(Obj? x)

  ** Data type for Fantom object
  abstract DataType? typeOf(Obj? val, Bool checked := true)

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