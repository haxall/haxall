//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Oct 2021  Matthew Giannini  Creation
//

class ListImagesCmd : DockerJsonCmd
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This|? f := null) : super(f)
  {
  }

  ** Show all images. Only images from a final layer (no childern)
  ** are shown by default.
  @JsonIgnore
  Bool showAll := false { private set }
  ** Set `showAll` and return this
  This withShowAll(Bool showAll) { this.showAll = showAll; return this }

  ** A JSON encoded value of the filters (a 'map[string][]string') to process
  ** on the image list.
  @JsonIgnore
  Str? filters { private set }
  ** Set the `filters` and return this
  This withFilters(Str? filters) { this.filters = filters; return this}

  ** Show digest information in `Images.repoDigets` field on each `Image`
  @JsonIgnore
  Bool showDigests := false { private set }
  ** Set the `showDigests` and return this
  This withShowDigests(Bool showDigests) { this.showDigests = showDigests; return this }

//////////////////////////////////////////////////////////////////////////
// DockerJsonCmd
//////////////////////////////////////////////////////////////////////////

  protected override Uri apiPath()
  {
    query := Str:Str[:]
    if (showAll) query["all"] = "true"
    if (filters != null) query["filters"] = filters
    if (showDigests) query["showDigests"] = "true"
    return `/images/json`.plusQuery(query)
  }

  protected override DockerHttpReqBuilder httpReq() { super.httpReq.withMethod("GET") }

  override DockerImage[] exec() { super.exec }
}