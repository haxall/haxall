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


const mixin ShellStdServices : HxStdServices
{
  abstract HxService service(Type type)
  override HxContextService context() { service(HxContextService#) }
  override HxObsService obs()         { service(HxObsService#) }
  override HxWatchService watch()     { service(HxWatchService#) }
  override HxFileService file()       { service(HxFileService#)  }
  override HxHisService his()         { service(HxHisService#) }
  override HxCryptoService crypto()   { service(HxCryptoService#) }
  override HxHttpService http()       { service(HxHttpService#) }
  override HxUserService user()       { service(HxUserService#) }
  override HxIOService io()           { service(HxIOService#) }
  override HxTaskService task()       { service(HxTaskService#) }
  override HxConnService conn()       { service(HxConnService#) }
  override HxPointWriteService pointWrite() { service(HxPointWriteService#) }
}

**************************************************************************
** ShellServiceRegistry
**************************************************************************

const class ShellServiceRegistry: HxServiceRegistry, ShellStdServices
{
  new make(ShellRuntime rt)
  {
    map := Type:HxService[][:]
    map[HxContextService#] = HxService[ShellContextService(rt)]
    map[HxFileService#] = HxService[ShellFileService()]

    this.list = map.keys.sort
    this.map  = map
  }

  override const Type[] list

  override HxService service(Type type) { get(type, true) }

  override HxService? get(Type type, Bool checked := true)
  {
    x := map[type]
    if (x != null) return x.first
    if (checked) throw UnknownServiceErr(type.qname)
    return null
  }

  override HxService[] getAll(Type type)
  {
    map[type] ?: HxService#.emptyList
  }

  private const Type:HxService[] map
}

**************************************************************************
** ShellContextService
**************************************************************************

internal const class ShellContextService : HxContextService
{
  new make(ShellRuntime rt) { this.rt = rt }

  const ShellRuntime rt

  override HxContext create(HxUser user) { throw UnsupportedErr() }

  override HxContext createSession(HxSession session) { throw UnsupportedErr() }

  override Void xetoReload() { rt.defs.xetoReload }
}

**************************************************************************
** ShellFileService
**************************************************************************

internal const class ShellFileService : HxFileService
{
  override File resolve(Uri uri) { File(uri, false) }
}

