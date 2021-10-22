//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Oct 2021  Matthew Giannini  Creation
//

class ListContainersCmd : DockerJsonCmd
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This|? f := null) : super(f)
  {
  }

  new makeConfig(DockerConfig config) : super(config)
  {
  }

  ** Show all containers. By default, only running containers are shown
  @JsonIgnore
  Bool showAll := false { private set }
  ** Set `showAll` and return this
  This withShowAll(Bool showAll) { this.showAll = showAll; return this }

  ** Filters to process on the container list, encoded as JSON
  ** (a 'map[string] []string').  For example, '{"status": ["paused"]}' will only
  ** return paused containers.
  @JsonIgnore
  Str? filters { private set }
  ** Set the `filters` and return this
  This withFilters(Str? filters) { this.filters = filters; return this }

//////////////////////////////////////////////////////////////////////////
// DockerJsonCmd
//////////////////////////////////////////////////////////////////////////

  protected override Uri apiPath()
  {
    query := Str:Str[:]
    if (showAll) query["all"] = "true"
    if (filters != null) query["filters"] = filters
    return `/containers/json`.plusQuery(query)
  }

  protected override HttpReqBuilder httpReq() { super.httpReq.withMethod("GET") }

  override Container[] exec() { super.exec }
}
