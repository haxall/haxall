//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using concurrent
using util

**
** Environment for the data processing subsystem.
** There is one instance for the VM accessed via `DataEnv.cur`.
**
@Js
const abstract class DataEnv
{
  ** Current default environment for the VM
  static DataEnv cur()
  {
    env := curRef.val as DataEnv
    if (env != null) return env
    curRef.compareAndSet(null, Type.find("xeto::XetoEnv").make)
    return curRef.val
  }
  private static const AtomicRef curRef := AtomicRef()

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

  ** Get the 'sys' library
  @NoDoc abstract DataLib sysLib()

  ** Compile Xeto source code into a temp library.
  ** Raise exception if there are any syntax or semantic errors.
  **
  ** Options:
  **   - log: '|DataLogRec|' or if omitted then log to stdout
  abstract DataLib compileLib(Str src, [Str:Obj]? opts := null)

  ** Compile Xeto data file into in-memory dict/scalar tree
  ** Raise exception if there are any syntax or semantic errors.
  **
  ** Options:
  **   - log: '|DataLogRec|' or if omitted then log to stdout
  abstract Obj? compileData(Str src, [Str:Obj]? opts := null)

  ** Derive a new spec from the given base type, additional meta, and
  ** slots.  The spec is not associated with any library and a synthetic
  ** qname is generated.
  abstract DataSpec derive(Str name, DataSpec base, DataDict meta, [Str:DataSpec]? slots := null)

  ** Get or load type by the given qualified name
  abstract DataType? type(Str qname, Bool checked := true)

  ** Pretty print object to output stream.
  abstract Void print(Obj? val, OutStream out := Env.cur.out, Obj? opts := null)

  ** Debug dump of environment
  @NoDoc abstract Void dump(OutStream out := Env.cur.out)

}