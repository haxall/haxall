//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

**
** DocId is an identifier a DocNode in the AST
**
@Js
const class DocId
{
  ** Constructor
  new make(DocNodeType nodeType, Uri uri, Str dis)
  {
    this.nodeType = nodeType
    this.uri      = uri
    this.dis      = dis
    this.link     = DocLink(this, dis)
  }

  ** Type of the node identified
  const DocNodeType nodeType

  ** Display text for the node
  const Str dis

  ** Default link to use to this id using dis
  const DocLink link

   ** URI relative to the document base such as "sys.comp/Comp"
  const Uri uri

  ** Debug string
  override Str toStr() { "$dis.toCode [$nodeType] $uri.toCode" }

}

