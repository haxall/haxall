//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using xetoEnv

**
** DocInstance is the documentation for an instance in a lib
**
@Js
const class DocInstance : DocPage
{
  ** Constructor
  new make(Str qname, DocDict instance)
  {
    this.qname    = qname
    this.instance = instance
  }

  ** URI relative to base dir to page
  override Uri uri() { DocUtil.qnameToUri(qname) }

  ** Qualified name of this instance
  const Str qname

  ** Library name for this instance
  once Str libName() { XetoUtil.qnameToLib(qname) }

  ** Simple name of this instance
  once Str name() { XetoUtil.qnameToName(qname) }

  ** Page type
  override DocPageType pageType() { DocPageType.instance }

  ** Library for this page
  override DocLibRef? lib() { DocLibRef(libName) }

  ** Instance dictionary
  const DocDict instance

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered     = true
    obj["page"]     = pageType.name
    obj["qname"]    = qname
    obj["instance"] = instance.encode
    return obj
  }

  ** Decode from a JSON object tree
  static DocInstance doDecode(Str:Obj obj)
  {
    qname    := obj.getChecked("qname")
    instance := DocDict.decode(obj.getChecked("instance"))
    return make(qname, instance)
  }

}

