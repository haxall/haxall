//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Jul 2022  Brian Frank  Garden City (split from MEnv)
//

using util
using concurrent
using xeto

**
** Remote client based environment used in browsers.
**
@Js
const class RemoteEnv : MEnv
{
  override Bool isRemote() { true }

  override LibRepo repo() { throw unavailErr() }

  override File homeDir() { throw unavailErr() }

  override File workDir() { throw unavailErr() }

  override File installDir() { throw unavailErr() }

  override File[] path() { throw unavailErr() }

  override Str:Str buildVars() { throw unavailErr() }

  override LibNamespace createNamespace(LibVersion[] libs)
  {
    RemoteNamespace(this, libs)
  }

  override LibNamespace createNamespaceFromNames(Str[] names) { throw unavailErr() }

  override LibNamespace createNamespaceFromData(Dict[] recs) { throw unavailErr() }

  override Str mode() { "browser" }

  override Str:Str debugProps() { Str:Obj[:] }

  override Void dump(OutStream out := Env.cur.out) {}

  static Err unavailErr() { Err("Not available in browser") }
}

