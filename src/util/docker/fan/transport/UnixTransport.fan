//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Oct 2021  Matthew Giannini  Creation
//

internal native class UnixTransport : DockerTransport
{
  new make(DockerConfig config)

  override OutStream out()

  override InStream in()

  override Void close()
}