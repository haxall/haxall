//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Mar 2022  Matthew Giannini  Creation
//

using inet

**
** Endpoint Settings
**
const class EndpointSettings : DockerObj
{
  new make(|This| f) : super(f)
  {
    f(this)
  }

  // TODO: IPAMConfig
  const Str[] links  := [,]

  const Str[] aliases := [,]

  ** The unique ID of the network
  const Str networkID

  ** The unique ID for the service endpoint in a sandbox
  const Str endpointID

  ** Gateway address for this network
  const Str gateway

  ** Convenience to get the IPv4 gateway address
  IpAddr? gatewayAddr() { toIpAddr(gateway) }

  ** IPv4 address
  const Str iPAddress

  ** Convenience to get the an `IpAddr` for the IPv4 address.
  IpAddr? ipv4() { toIpAddr(iPAddress) }

  ** Mask length of the IPv4 address
  const Int iPPrefixLen

  ** IPV5 gateway address
  const Str iPv6Gateway

  ** Convenience to get the IPv6 gateway address
  IpAddr? gateway6() { toIpAddr(iPv6Gateway) }

  ** Global IPv6 address
  const Str globalIPv6Address

  ** Convenience to get the an `IpAddr` for the IPv6 address.
  IpAddr? ipv6() { toIpAddr(globalIPv6Address) }

  ** Mask length of the global IPv6 address
  const Int globalIPv6PrefixLen

  private IpAddr? toIpAddr(Str v)
  {
    v.trimToNull == null ? null : IpAddr(v)
  }

  // TODO: DriverOpts
}
