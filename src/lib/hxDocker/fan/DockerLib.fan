//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2021  Matthew Giannini  Creation
//

using haystack
using hx

**
** Docker image management
**
const class DockerLib : HxLib
{
  new make()
  {
    dockerMgr = DockerMgrActor(this)
  }

  internal const DockerMgrActor dockerMgr

  ** Publish the HxDockerService
  override HxService[] services() { [dockerMgr] }

  ** Stop callback
  override Void onStop()
  {
    dockerMgr.shutdown
  }
}