//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Nov 2024  Brian Frank  Creation
//

using xetom

**
** DocChapter is a page in a markdown document
**
@Js
const class DocChapter : DocPage
{
  ** Constructor
  new make(DocLibRef lib, Str qname, Str title, DocMarkdown doc, DocLink? prev, DocLink? next)
  {
    this.lib   = lib
    this.qname = qname
    this.title = title
    this.doc   = doc
    this.prev  = prev
    this.next  = next
  }

  ** URI relative to base dir to page
  override Uri uri() { DocUtil.qnameToUri(qname) }

  ** Title
  override const Str title

  ** Qualified name of this chapter
  const Str qname

  ** Library name for this instance
  once Str libName() { XetoUtil.qnameToLib(qname) }

  ** Simple name of this instance
  once Str name() { XetoUtil.qnameToName(qname) }

  ** Page type
  override DocPageType pageType() { DocPageType.chapter }

  ** Library for this page
  override const DocLibRef? lib

  ** Previous chapter in library
  const DocLink? prev

  ** Next chapter in library
  const DocLink? next

  ** Markdown
  const DocMarkdown doc

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered  = true
    obj["page"]  = pageType.name
    obj["lib"]   = lib.encode
    obj["qname"] = qname
    obj["title"] = title
    obj["doc"]   = doc.encode
    if (prev != null) obj["prev"] = prev.encode
    if (next != null) obj["next"] = next.encode
    return obj
  }

  ** Decode from a JSON object tree
  static DocChapter doDecode(Str:Obj obj)
  {
    lib   := DocLibRef.decode(obj.getChecked("lib"))
    qname := obj.getChecked("qname")
    title := obj.getChecked("title")
    doc   := DocMarkdown.decode(obj.getChecked("doc"))
    prev  := DocLink.decode(obj["prev"])
    next  := DocLink.decode(obj["next"])
    return make(lib, qname, title, doc, prev, next)
  }

}

