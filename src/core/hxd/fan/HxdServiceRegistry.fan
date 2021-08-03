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
  new make(HxLib[] libs)
  {
    list := Type[,]
    map := Str:HxService[][:]
    serviceType := HxService#

    libs.each |lib|
    {
      lib.typeof.inheritance.each |t|
      {
        if (t.mixins.containsSame(serviceType))
        {
          bucket := map[t.qname]
          if (bucket == null)
          {
            list.add(t)
            map[t.qname] = bucket = HxService[,]
          }
          bucket.add((HxService)lib)
        }
      }
    }


    this.list = list.sort
    this.map = map
    this.pointWrite = get(HxPointWriteService#, false) ?: NilPointWriteService()
  }

  const override Type[] list

  const override HxPointWriteService pointWrite

  override HxService? get(Type type, Bool checked := true)
  {
    x := map[type.qname]
    if (x != null) return x.first
    if (checked) throw UnknownServiceErr(type.qname)
    return null
  }

  override HxService[] getAll(Type type)
  {
    map[type.qname] ?: HxService#.emptyList
  }

  private const Str:HxService[] map
}