//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 May 2023  Brian Frank  Creation
//

using xeto

**
** Platform service provider interface for IP network config
**
** IP interfaces are modeled as a Dict.  All interface types must
** provide the following tags:
**   - name: Str identifier for the interface
**   - dis: Str friendly user display name
**   - type: Str ethernet, wifi
**   - static: Str up, down, disabled
**
** Ethernet type interfaces support following tags:
**   - mode: Str dhcp, static
**   - modes: comma separated Str of available mode types
**   - ip: Str formatted as IPv4 dotted address
**   - router: Str formatted as IPv4 dotted address
**   - mask: Str formatted as IPv4 dotted address
**   - dns: Str[] of DNS servers as IPv4 dotted addresses
**   - mac: Str optional MAC address for display purposes
**
** Wifi type interfaces support following tags:
**   - TODO: not complete yet
**
const mixin PlatformNetworkSpi
{
  ** List the installed IP interface.
  ** See class header for modeling details.
  abstract Dict[] interfaces()

  ** Write the configuration for an IP interface.
  ** See class header for modeling details.
  abstract Void interfaceSet(Dict config)
}

