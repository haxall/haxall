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
    curRef.compareAndSet(null, Type.find("xetoImpl::XetoEnv").make)
    return curRef.val
  }
  private static const AtomicRef curRef := AtomicRef()

  ** Reload the entire data env.  This creates a new environment,
  ** rescans the local file system for installed libs, and all previously
  ** loaded libraries with be reloaded on first access.  Any
  ** references to DataLib or DataSpecs must no longer be used.
  static Void reload()
  {
    curRef.val = Type.find("xetoImpl::XetoEnv").make
  }

  ** None singleton value
  abstract Obj none()

  ** Marker singleton value
  abstract Obj marker()

  ** NA singleton value
  abstract Obj na()

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

  ** Registry of installed libs
  @NoDoc abstract DataRegistry registry()

  ** Get or load library by the given qualified name
  abstract DataLib? lib(Str qname, Bool checked := true)

  ** Get the 'sys' library
  @NoDoc abstract DataLib sysLib()

  ** Get or load type by the given qualified name
  abstract DataType? type(Str qname, Bool checked := true)

  ** Get or load spec by the given qualified name:
  **   - lib: "foo.bar"
  **   - type: "foo.bar::Baz"
  **   - slot: "foo.bar::Baz.qux"
  abstract DataSpec? spec(Str qname, Bool checked := true)

  ** Derive a new spec from the given base type, additional meta, and
  ** slots.  The spec is not associated with any library and a synthetic
  ** qname is generated.
  abstract DataSpec derive(Str name, DataSpec base, DataDict meta, [Str:DataSpec]? slots := null)

  ** Create default instance for the given spec.
  ** Raise exception if spec is abstract.
  **
  ** Options:
  **   - 'graph': marker tag to instantiate graph of recs
  **   - 'abstract': marker to supress error if spec is abstract
  abstract Obj? instantiate(DataSpec spec, DataDict? opts := null)

  ** Compile Xeto source code into a temp library.
  ** Raise exception if there are any syntax or semantic errors.
  abstract DataLib compileLib(Str src, DataDict? opts := null)

  ** Compile Xeto data file into in-memory dict/scalar tree
  ** Raise exception if there are any syntax or semantic errors.
  abstract Obj? compileData(Str src, DataDict? opts := null)

  ** Parse pragma file into AST
  @NoDoc abstract DataDict parsePragma(File file, DataDict? opts := null)

  ** Parse instance of DataLibDependVersions
  @NoDoc abstract DataLibDependVersions parseLibDependVersions(Str s, Bool checked)

  ** Return if the given instance fits the spec via structural typing.
  abstract Bool fits(DataContext cx, Obj? val, DataSpec spec, DataDict? opts := null)

  ** Return if spec 'a' fits spec 'b' based on structural typing.
  @NoDoc abstract Bool specFits(DataSpec a, DataSpec b, DataDict? opts := null)

  ** Query a relationship using the given subject and query spec.
  ** Call given callback function until it returns non-null and return
  ** as overall result of the method.
  @NoDoc abstract Obj? queryWhile(DataContext cx, DataDict subject, DataSpec query, DataDict? opts, |DataDict->Obj?| f)

  ** Generate an AST for the given spec as a Dict tree.
  @NoDoc abstract DataDict genAst(DataSpec spec, DataDict? opts := null)

  ** Pretty print object to output stream.
  @NoDoc abstract Void print(Obj? val, OutStream out := Env.cur.out, DataDict? opts := null)

  ** Debug dump of environment
  @NoDoc abstract Void dump(OutStream out := Env.cur.out)

}