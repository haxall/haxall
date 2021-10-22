//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Oct 2021  Matthew Giannini  Creation
//

internal mixin DockerTransport
{
  static DockerTransport open(DockerConfig config)
  {
    switch (config.hostScheme)
    {
      case "npipe":
        return WinTransport(config)
      default:
        throw IOErr("Unsupported URI: ${config.daemonHost}")
    }
  }

  abstract OutStream out()

  abstract InStream in()

  abstract Void close()
}