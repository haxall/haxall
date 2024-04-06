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
** Environment for the Xeto data and spec handling.
** There is one instance for the VM accessed via `XetoEnv.cur`.
**
@Js
const abstract class XetoEnv
{
  ** Current default environment for the VM
  static XetoEnv cur()
  {
    env := curRef.val as XetoEnv
    if (env != null) return env
    curRef.compareAndSet(null, Type.find("xetoc::LocalEnv").make)
    return curRef.val
  }
  private static const AtomicRef curRef := AtomicRef()

  ** Install an environment only if one is not currently installed
  @NoDoc
  static Void install(XetoEnv env)
  {
    curRef.compareAndSet(null, env)
  }

  ** Reload the entire data env.  This creates a new environment,
  ** rescans the local file system for installed libs, and all previously
  ** loaded libraries with be reloaded on first access.  Any
  ** references to Lib or Specs must no longer be used.
  static Void reload()
  {
    curRef.val = Type.find("xetoc::LocalEnv").make
  }

  ** Is this a remote environment loaded over a network transport.
  ** Remote environments must load libraries asynchronously and do
  ** not support the full feature set.
  abstract Bool isRemote()

  ** Return generic 'sys::Dict'
  @NoDoc abstract Spec dictSpec()

  ** Spec for Fantom `sys::Type` or the typeof given object
  abstract Spec? specOf(Obj? val, Bool checked := true)

  ** Name table for this environment
  @NoDoc abstract NameTable names()

  ** Registry of installed libs
  @NoDoc abstract LibRegistry registry()

  ** Get or load library by the given library name.
  ** If the library is found but cannot be compiled, then raise an exception.
  abstract Lib? lib(Str name, Bool checked := true)

  ** Get or load library asynchronously by the given library name.
  ** Once loaded then invoke callback with library or err.
  abstract Void libAsync(Str name, |Err?, Lib?| f)

  ** Load a list of library names asynchronously and invoke callback once
  ** all are loaded.
  @NoDoc abstract Void libAsyncList(Str[] names, |Err?| f)

  ** Get the 'sys' library
  @NoDoc abstract Lib sysLib()

  ** Get or load type by the given qualified name
  abstract Spec? type(Str qname, Bool checked := true)

  ** Get or load spec by the given qualified name:
  **   - type: "foo.bar::Baz"
  **   - slot: "foo.bar::Baz.qux"
  abstract Spec? spec(Str qname, Bool checked := true)

  ** Get or load instance by the given qualified name
  abstract Dict? instance(Str qname, Bool checked := true)

  ** Create default instance for the given spec.
  ** Raise exception if spec is abstract.
  **
  ** Options:
  **   - 'graph': marker tag to instantiate graph of recs (will auto-generate ids)
  **   - 'abstract': marker to supress error if spec is abstract
  **   - 'id': Ref tag to include in new instance
  abstract Obj? instantiate(Spec spec, Dict? opts := null)

  ** Compile Xeto source code into a temp library.
  ** Raise exception if there are any syntax or semantic errors.
  abstract Lib compileLib(Str src, Dict? opts := null)

  ** Compile a Xeto data file into an in-memory value. Raise exception if
  ** there are any syntax or semantic errors.  If the file contains a scalar
  ** value or one dict, then it is returned as the value.  If the file contains
  ** two or more dicts then return a Dict[] of the instances.  Also
  ** see `writeData` to encode data back to Xeto text format.
  **
  ** Options
  **   - externRefs: marker to allow unresolved refs to compile
  abstract Obj? compileData(Str src, Dict? opts := null)

  ** Convenience for `compileData` but always returns data as list of dicts.
  ** If the data is not a Dict nor list of Dicts, then raise an exception.
  abstract Dict[] compileDicts(Str src, Dict? opts := null)

  ** Write instance data in Xeto text format to an output stream.  If the
  ** value is a Dict[], then it is flattened in the output.  Use `compileData`
  ** to read data from Xeto text format.
  abstract Void writeData(OutStream out, Obj val, Dict? opts := null)

  ** Parse pragma file into AST
  @NoDoc abstract Dict parsePragma(File file, Dict? opts := null)

  ** Given an instance and choice base type, return the selected choice.
  ** If instance has zero or more than one choice, then return null or
  ** raise an exception based on the checked flag.
  ** Example:
  **   choiceOf({hot, water, point}, Fluid)  >>  HotWater
  @NoDoc abstract Spec? choiceOf(Dict instance, Spec choice, Bool checked := true)

  ** Generate an AST for the given Lib or Spec as a Dict tree.
  @NoDoc abstract Dict genAst(Obj libOrSpec, Dict? opts := null)

  ** Pretty print object to output stream.
  @NoDoc abstract Void print(Obj? val, OutStream out := Env.cur.out, Dict? opts := null)

  ** Debug dump of environment
  @NoDoc abstract Void dump(OutStream out := Env.cur.out)

}

