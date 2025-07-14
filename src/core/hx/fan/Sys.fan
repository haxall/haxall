//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//   13 Jul 2025  Brian Frank  Redesign from HxRuntimeLibs
//

**
** System is the host level project in multi-tenant systems
**
const mixin Sys : Proj
{

  ** Platform hosting the runtime
  abstract Platform platform()

  ** System version
  abstract Version version()

  ** Cluster system extension
  @NoDoc abstract IClusterExt? cluster(Bool checked := true)

  ** Crypto system extension
  @NoDoc abstract ICryptoExt crypto()

  ** HTTP system extension
  abstract IHttpExt http()

  ** User management system extension
  abstract IUserExt user()

  ** Configuration options defined at bootstrap
  @NoDoc abstract SysConfig config()

}

