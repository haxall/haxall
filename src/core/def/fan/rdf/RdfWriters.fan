//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jan 2019  Matthew Giannini  Creation
//

using rdf
using xeto
using haystack

**
** Turtle Writer
**
@NoDoc @Js class TurtleWriter : RdfWriter
{
  new make(OutStream out, Dict? opts := null) : super(TurtleOutStream(out), opts)
  {
  }
}

**
**JSON-LD Writer
**
@NoDoc @Js class JsonLdWriter : RdfWriter
{
  new make(OutStream out, Dict? opts := null) : super(JsonLdOutStream(out), opts)
  {
  }
}

