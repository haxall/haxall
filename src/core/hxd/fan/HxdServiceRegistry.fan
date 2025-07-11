//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2021  Brian Frank  Creation
//

using concurrent
using haystack
using hx

**
** HxdServiceRegistry
**
const class HxdServiceRegistry : HxServiceRegistry
{
  ** Construct for list of enabled libs
  new make(HxdRuntime rt, Ext[] libs)
  {
    map := Type:HxService[][:]
    serviceType := HxService#

    libs.each |lib|
    {
      lib.services.each |service|
      {
        service.typeof.inheritance.each |t|
        {
          if (t.mixins.containsSame(serviceType))
          {
            bucket := map[t]
            if (bucket == null) map[t] = bucket = HxService[,]
            bucket.add(service)
          }
        }
      }
    }

    // these are built-in without using a lib
    map[HxContextService#] = HxService[rt.context]
    map[HxObsService#]     = HxService[rt.obs]
    map[HxWatchService#]   = HxService[rt.watch]
    map[HxFileService#]    = HxService[rt.file]
    map[HxHisService#]     = HxService[rt.his]

    // we might need to stub http since its not added by default in tests
    if (map[HxHttpService#] == null)
      map[HxHttpService#] = HxService[NilHttpService()]

    // ensure pointWrite service is defined
    if (map[HxPointWriteService#] == null)
      map[HxPointWriteService#] = HxService[NilPointWriteService()]

    // ensure conn service is defined
    if (map[HxConnService#] == null)
      map[HxConnService#] = HxService[NilConnService()]

    this.list = map.keys.sort
    this.map  = map

    this.context    = get(HxContextService#)
    this.obs        = get(HxObsService#)
    this.watch      = get(HxWatchService#)
    this.crypto     = get(HxCryptoService#)
    this.httpRef    = get(HxHttpService#, false)
    this.user       = get(HxUserService#)
    this.ioRef      = get(HxIOService#, false)
    this.file       = get(HxFileService#)
    this.taskRef    = get(HxTaskService#, false)
    this.his        = get(HxHisService#)
    this.pointWrite = get(HxPointWriteService#)
    this.conn       = get(HxConnService#)
  }

  override const Type[] list

  override const HxdContextService context

  override const HxdObsService obs

  override const HxWatchService watch

  override const HxFileService file

  override const HxHisService his

  override const HxCryptoService crypto

  override HxHttpService http() { httpRef ?: throw UnknownServiceErr("HxHttpService") }
  private const HxHttpService? httpRef

  override const HxUserService user

  override HxIOService io() { ioRef ?: throw UnknownServiceErr("HxIOService") }
  private const HxIOService? ioRef

  override HxTaskService task() { taskRef ?: throw UnknownServiceErr("HxTaskService") }
  private const HxTaskService? taskRef

  override const HxPointWriteService pointWrite

  override const HxConnService conn

  override HxService? get(Type type, Bool checked := true)
  {
    x := map[type]
    if (x != null) return x.first
    if (checked) throw UnknownServiceErr(type.qname)
    return null
  }

  override HxService[] getAll(Type type)
  {
    map[type] ?: emptyList
  }

  private static const HxService[] emptyList := HxService[,]

  private const Type:HxService[] map
}

