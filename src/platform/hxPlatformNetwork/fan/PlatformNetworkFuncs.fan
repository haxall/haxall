//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 May 2023  Brian Frank  Creation
//

using axon
using xeto
using haystack
using hx

**
** Axon library
**
@NoDoc
const class PlatformNetworkFuncs
{
  ** Get the status and configuration for a given IP interface by name.
  ** Return results a Dict.  See SPI class docs for modeling details.
  @Api @Axon { su = true }
  static Dict platformNetworkInterfaceGet(Str name)
  {
    ext.platformSpi.interfaces.find { it->name == name } ?: throw Err("Unknown interface: $name")
  }

  ** Write the configure of an IP interface.  The config must
  ** be a dict that defines the 'name' tag for an existing interface.
  ** See SPI class docs for modeling details.
  @Api @Axon { su = true }
  static Obj? platformNetworkInterfaceSet(Dict config)
  {
    ext.platformSpi.interfaceSet(config)
    return config
  }

  ** Return grid of summary information used to populate UI.
  ** This is a nodoc method subject to change
  @NoDoc @Api @Axon { su = true }
  static Grid platformNetworkInfo()
  {
    cx  := curContext
    ext := ext(cx)
    now := DateTime.now
    gb  := GridBuilder().addCol("dis").addCol("val").addCol("icon").addCol("edit").addCol("name")

    ext.platformSpi.interfaces.each |d|
    {
      gb.addRow([d.dis, "___", infoIcon(d->type), d->type, d->name])
      d.each |v, n|
      {
        if (infoSkip(n)) return
        gb.addRow([infoDis(n), infoVal(v), null, null, null])
      }
    }

    return gb.toGrid
  }

  private static Bool infoSkip(Str n)
  {
    n == "dis" || n == "modes"
  }

  private static Str infoDis(Str n)
  {
    if (n == "ip") return "IP Address"
    if (n == "dns") return "DNS"
    if (n == "mac") return "MAC"
    return n.toDisplayName
  }

  private static Str infoVal(Obj x)
  {
    if (x is List) return ((List)x).join(", ")
    return x.toStr
  }

  private static Str infoIcon(Str type)
  {
    if (type == "ethernet") return "equip"
    if (type == "wifi") return "wifi"
    return "network"
  }

  private static Dict pi(Str section, Str dis, Str val)
  {
    Etc.dict3("section", section, "dis", dis, "val", val)
  }

  private static Context curContext()
  {
    Context.cur
  }

  private static PlatformNetworkExt ext(Context cx := curContext)
  {
    cx.rt.ext("hx.platform.network")
  }
}

