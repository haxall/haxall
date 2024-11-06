//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Nov 2024  Brian Frank  Creation
//

using xetoEnv

**
** DocChapter is a page of a markdown document
**
@Js
const class DocChapter : DocPage
{
  ** Constructor
  new make(Str qname, DocMarkdown doc)
  {
    this.qname = qname
    this.doc   = doc
  }

  ** URI relative to base dir to page
  override Uri uri() { DocUtil.chapterToUri(qname) }

  ** Qualified name of this chapter
  const Str qname

  ** Library name for this instance
  once Str libName() { XetoUtil.qnameToLib(qname) }

  ** Simple name of this instance
  once Str name() { XetoUtil.qnameToName(qname) }

  ** Page type
  override DocPageType pageType() { DocPageType.chapter }

  ** Library for this page
  override DocLibRef? lib() { DocLibRef(libName) }

  ** Markdown
  const DocMarkdown doc

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered  = true
    obj["page"]  = pageType.name
    obj["qname"] = qname
    obj["doc"]   =doc.encode
    return obj
  }

  ** Decode from a JSON object tree
  static DocChapter doDecode(Str:Obj obj)
  {
    qname := obj.getChecked("qname")
    doc   := DocMarkdown.decode(obj.getChecked("doc"))
    return make(qname, doc)
  }

}

