//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Mar 2022  Matthew Giannini  Creation
//

using inet
using docker
using hx

**************************************************************************
** MHxDockerContainer
**************************************************************************

@NoDoc
internal const class MHxDockerContainer : HxDockerContainer
{
  new make(DockerContainer container)
  {
    this.container = container
  }

  const DockerContainer container

  override Str id() { container.id }

  override Str[] names() { container.names }

  override Str image() { container.image }

  override DateTime created() { container.createdAt }

  override Str state() { container.state }

  override MHxDockerEndpoint? network(Str name)
  {
    e := container.network(name)
    if (e == null) return null
    return MHxDockerEndpoint(e)
  }

}

**************************************************************************
** MHxDockerEndpoint
**************************************************************************

@NoDoc
internal const class MHxDockerEndpoint : HxDockerEndpoint
{
  new make(EndpointSettings settings)
  {
    this.settings = settings
  }

  const EndpointSettings settings

  override IpAddr? gateway() { settings.gatewayAddr }

  override IpAddr? ip() { settings.ipv4 }

  override IpAddr? gateway6() { settings.gateway6 }

  override IpAddr? ip6() { settings.ipv6 }
}