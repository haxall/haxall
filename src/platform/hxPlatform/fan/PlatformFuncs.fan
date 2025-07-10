//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 May 2023  Brian Frank  Creation
//

using xeto
using haystack
using axon
using hx

**
** Axon library
**
@NoDoc
const class PlatformFuncs
{
  ** Reboot the operating system and runtime process
  @Axon { su = true }
  static Void platformReboot() { lib.platformSpi.reboot }

  ** Restart runtime process, but do not reboot operating system
  @Axon { su = true }
  static Void platformRestart() { lib.platformSpi.restart }

  ** Shutdown operating system and runtime process
  @Axon { su = true }
  static Void platformShutdown() { lib.platformSpi.shutdown }

  ** Return grid of summary information used to populate UI.
  ** This is a nodoc method subject to change
  @NoDoc @Axon { su = true }
  static Grid platformInfo()
  {
    cx := curContext
    info := platformInfoDefaults(cx.rt)
            .addAll(lib(cx).platformSpi.info)
    gb := GridBuilder().addCol("dis").addCol("val").addCol("icon")
    platformInfoSection(gb, info, "sw",   "Software", "host")
    platformInfoSection(gb, info, "hw",   "Hardware", "cpu")
    platformInfoSection(gb, info, "os",   "OS", "hdd")
    platformInfoSection(gb, info, "java", "Java", "java")
    return gb.toGrid
  }

  private static Void platformInfoSection(GridBuilder gb, Dict[] info, Str name, Str dis, Str icon)
  {
    matches := info.findAll |x| { x["section"] == name }
    if (matches.isEmpty) return
    gb.addRow([dis, "___", icon])
    matches.each |r| { gb.addRow([r["dis"], r["val"], null]) }
  }

  private static Dict[] platformInfoDefaults(HxRuntime rt)
  {
    env := Env.cur.vars
    now := DateTime.now
    return [
      pi("sw",     "Name",     rt.platform.productName),
      pi("sw",     "Version",  rt.platform.productVersion),
      pi("sw",     "Time",     now.time.toLocale + " " + now.date.toLocale + now.tz.name),
      pi("sw",     "Uptime",   Duration.uptime.toLocale),
      pi("os",     "Name",     env["os.name"] + " " + env["os.arch"]),
      pi("os",     "Version",  env["os.version"]),
      pi("java",   "Name",     env["java.vm.name"] + " " + env["java.vm.version"]),
      pi("java",   "Version",  env["java.version"]),
    ]
  }

  private static Dict pi(Str section, Str dis, Str val)
  {
    Etc.dict3("section", section, "dis", dis, "val", val)
  }

  private static HxContext curContext()
  {
    HxContext.curHx
  }

  private static PlatformLib lib(HxContext cx := curContext)
  {
    cx.rt.libsOld.get("platform")
  }
}

