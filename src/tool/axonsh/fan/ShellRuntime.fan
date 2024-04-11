//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Mar 2023  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx

**
** ShellRuntime implements a limited, single-threaded runtime for the shell.
**
const class ShellRuntime : HxRuntime, ShellStdServices
{
  new make()
  {
    this.name     = "axonsh"
    this.dir      = Env.cur.workDir + `axonsh/`
    this.version  = typeof.pod.version
    this.platform = HxPlatform(Etc.dict1("axonsh", Marker.val))
    this.config   = HxConfig(Etc.dict0)
    this.db       = ShellFolio(FolioConfig { it.name = this.name; it.dir = this.dir })
    this.ns       = ShellNamespace.init(this)
  }

  override const Str name

  override Str dis() { name }

  override const File dir

  override const Version version

  override const HxPlatform platform

  override const HxConfig config

  override const Folio db

  override const ShellNamespace ns

  override Dict meta() { Etc.dict0 }

  override HxLib? lib(Str name, Bool checked := true) { libs.get(name, checked) }

  override HxRuntimeLibs libs() { throw UnsupportedErr() }

  override Bool isSteadyState() { true }

  override This sync(Duration? timeout := 30sec) { this }

  override Bool isRunning() { true }

  override HxService service(Type type) { services.get(type, true) }

  override const ShellServiceRegistry services := ShellServiceRegistry(this)
}

