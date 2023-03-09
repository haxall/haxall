//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Mar 2023  Brian Frank  Creation
//

using haystack
using folio
using hx

**
** ShellRuntime implements a limited, single-threaded runtime for the shell.
**
internal const class ShellRuntime : HxRuntime
{
  new make()
  {
    this.name     = "axonsh"
    this.dir      = Env.cur.workDir + `axonsh/`
    this.version  = typeof.pod.version
    this.platform = HxPlatform(Etc.dict0)
    this.config   = HxConfig(Etc.dict0)
    this.db       = ShellFolio(FolioConfig { it.name = this.name; it.dir = this.dir })
  }

  override const Str name

  override const File dir

  override const Version version

  override const HxPlatform platform

  override const HxConfig config

  override const Folio db

  override Namespace ns() { throw UnsupportedErr() }

  override Dict meta() { Etc.dict0 }

  override HxLib? lib(Str name, Bool checked := true) { libs.get(name, checked) }

  override HxRuntimeLibs libs() { throw UnsupportedErr() }

  override Bool isSteadyState() { true }

  override This sync(Duration? timeout := 30sec) { this }

  override Bool isRunning() { true }

  override HxServiceRegistry services() { throw UnsupportedErr() }

  // HxStdServices conveniences
  override HxContextService context() { services.context }
  override HxObsService obs() { services.obs }
  override HxWatchService watch() { services.watch }
  override HxFileService file() { services.file }
  override HxHisService his() { services.his }
  override HxCryptoService crypto() { services.crypto }
  override HxHttpService http() { services.http }
  override HxUserService user() { services.user }
  override HxIOService io() { services.io }
  override HxTaskService task() { services.task }
  override HxPointWriteService pointWrite() { services.pointWrite }
  override HxConnService conn() { services.conn }

}