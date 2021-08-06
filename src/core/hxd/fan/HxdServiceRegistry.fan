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
  new make(HxdRuntime rt, HxLib[] libs)
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
    map[HxObsService#] = HxService[rt.obs]
    map[HxWatchService#] = HxService[rt.watch]

    // we might need to stub http since its not added by default in tests
    if (map[HxHttpService#] == null)
      map[HxHttpService#] = HxService[NilHttpService()]

    // ensure pointWrite service is defined
    if (map[HxPointWriteService#] == null)
      map[HxPointWriteService#] = HxService[NilPointWriteService()]

    // ensure conns service is defined
    if (map[HxConnRegistryService#] == null)
      map[HxConnRegistryService#] = HxService[NilConnRegistryService()]

    this.list = map.keys.sort
    this.map  = map

    this.obs        = get(HxObsService#)
    this.watch      = get(HxWatchService#)
    this.httpRef    = get(HxHttpService#, false)
    this.user       = get(HxUserService#)
    this.pointWrite = get(HxPointWriteService#)
    this.conns      = get(HxConnRegistryService#)
  }

  override const Type[] list

  override const HxdObsService obs

  override const HxWatchService watch

  override HxHttpService http() { httpRef ?: throw UnknownServiceErr("HxHttpService") }
  private const HxHttpService? httpRef

  override const HxUserService user

  override const HxPointWriteService pointWrite

  override const HxConnRegistryService conns

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


