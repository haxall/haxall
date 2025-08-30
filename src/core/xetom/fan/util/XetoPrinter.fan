//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2025  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** XetoPrinter is used to print Xeto source code for specs and instances
**
@Js
class XetoPrinter
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(LibNamespace ns, OutStream out := Env.cur.out, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    this.ns   = ns
    this.out  = out
    this.opts = opts
    this.omitSpecName = opts.has("omitSpecName")
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  ** Start new top-level spec or slot spec:
  **   // doc from meta
  **   name: type <meta>
  This specHeader(Str name, Obj type, Dict meta := Etc.dict0)
  {
    doc := meta["doc"] as Str
    if (doc != null) this.doc(doc)
    if (!omitSpecName) w(name).wc(':').sp
    this.type(type).meta(meta)
    return this
  }

  ** Always skip these which should be encoded outside of meta
  static const Str[] metaSkip := ["axon", "axonTree", "compTree", "compTree", "doc", "maybe", "val"]

  ** Write meta data dict. We always skip the skipMeta tags by default
  This meta(Dict meta, Str[] skip := metaSkip)
  {
    // get keys to print
    keys := Str[,]
    meta.each |v, n|
    {
      if (!skip.contains(n)) keys.add(n)
    }
    if (keys.isEmpty) return this

    // put keys in nice order
    keys.sort
    keys.moveTo("su", 0)
    keys.moveTo("admin", 0)
    keys.moveTo("nodoc", 0)
    keys.moveTo("defMeta", -1)

    sp.wc('<')
    keys.each |k, i|
    {
      if (i > 0) wc(',').sp
      dictPair(k, meta[k])
    }
    return wc('>')
  }

  ** Encode inline meta as heredoc using current indentation
  This metaInline(Str name, Str val)
  {
    wc('<').w(name).wc(':').sp.heredoc(val).wc('>')
  }

  ** Write a slot spec out using current indentation
  This slot(Spec slot)
  {
    oldOmit := this.omitSpecName
    this.omitSpecName = false
    tab.specHeader(slot.name, slot.type, slot.meta).nl
    this.omitSpecName = oldOmit
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Instance Data
//////////////////////////////////////////////////////////////////////////

  ** Top level for LibNamespace.writeData
  This data(Obj top)
  {
    if (top is Grid)
    {
      ((Grid)top).each(dataIterator)
    }
    else if (XetoUtil.isDictList(top))
    {
      ((Dict[])top).each(dataIterator)
    }
    else if (top is Dict && ((Dict)top).has("id"))
    {
      instance(top)
    }
    else
    {
      val(top)
    }
    return this
  }

  private |Dict,Int| dataIterator()
  {
    |Dict x, Int i| { if (i > 0) nl; instance(x) }
  }

  ** Instance:
  **   @id: Spec {
  **     n0: v0
  **     ...
  **   }
  This instance(Dict x, Str[] skip := dictSkip)
  {
    // leading id
    id := x["id"] as Ref
    if (id != null)
    {
      id = XetoUtil.qnameToName(id) ?: id
      wc('@').w(id).wc(':').sp
    }

    dict(specOf(x), x).nl
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Literals
//////////////////////////////////////////////////////////////////////////

  ** Literal value
  This val(Obj x)
  {
    spec := specOf(x)
    if (spec.isScalar) return scalar(spec, x)
    if (x is Dict) return dict(spec, x)
    if (x is List) return list(spec, x)
    return scalar(strSpec, x.toStr)
  }

  ** Scalar
  This scalar(Spec spec, Obj x)
  {
    if (x is Ref) return ref(x)
    if (x isnot Str) type(spec).sp

    str := spec.binding.encodeScalar(x)
    if (str.contains("\n")) indent.heredoc(str).unindent
    else quoted(str)
    return this
  }

  ** Ref scalar
  This ref(Ref x)
  {
    w("@").w(x.id)
    if (x.disVal != null) sp.quoted(x.disVal)
    return this
  }

  ** Standard dict skip tags
  static const Str[] dictSkip := ["id", "spec"]

  ** Dict value
  This dict(Spec spec, Dict x, Str[] skip := dictSkip)
  {
    if (spec.qname != "sys::Dict") type(spec).sp
    wc('{')
    num := 0
    indent
    x.each |v, n|
    {
      if (skip.contains(n)) return
      num++
      nl.tab.dictPair(n, v)
    }
    unindent
    if (num > 0) nl.tab
    return wc('}')
  }

  ** List value
  This list(Spec spec, List list)
  {
    type(spec).sp.wc('{')
    num := 0
    indent
    list.each |v|
    {
      num++
      nl.tab.dictPair("_0", v) // force use of fixed auto-name
    }
    unindent
    if (num > 0) nl.tab
    return wc('}')
  }

  ** Dict pair
  This dictPair(Str? n, Obj v)
  {
    // name only
    if (isMarker(v)) return w(n)

    // name @id: value
    showName  := !XetoUtil.isAutoName(n)
    id        := (v as Dict)?.get("id") as Ref
    needColon := showName || id != null

    if (showName) w(n)
    if (id != null)
    {
      if (showName) sp
      ref(id.noDis)
    }
    if (needColon) wc(':').sp

    return val(v)
  }

//////////////////////////////////////////////////////////////////////////
// Grammar Utils
//////////////////////////////////////////////////////////////////////////

  ** Write doc lines as // comments
  This doc(Str? str)
  {
    str = str?.trimToNull
    if (str == null) return this
    str.eachLine |line|
    {
      w("//")
      if (!line.trim.isEmpty) sp.w(line.trimEnd)
      nl
    }
    return this
  }

  ** Write type name where type can be string like "Str?" or a Spec
  This type(Obj type)
  {
    name := type is Spec ? ((Spec)type).qname : type.toStr
    return w(name)
  }

  ** Quoted string literal (we use our own since we don't escape $ like Fantom)
  This quoted(Str x)
  {
    wc('"')
    x.each |c|
    {
      esc := c < 127 ? XetoUtil.strEscapes.get(c) : null
      if (esc == null) wc(c)
      else w(esc)
    }
    return wc('"')
  }

  ** Write heredoc string literal (uses current indentation level)
  This heredoc(Str x)
  {
    lines := x.splitLines
    while (lines.last.isEmpty) lines.removeAt(-1)

    sep := "---"
    lines.each |line| { while(line.contains(sep)) sep += "-" }

    w(sep).nl
    lines.each |line|
    {
      tab.w(line).nl
    }
    tab.w(sep)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Namespace Utils
//////////////////////////////////////////////////////////////////////////

  private once Spec strSpec() { ns.sysLib.spec("Str") }

  private Spec specOf(Obj? val) { ns.specOf(val) }

  private Bool isMarker(Obj? val) { val === Marker.val }

//////////////////////////////////////////////////////////////////////////
// OutStream Utils
//////////////////////////////////////////////////////////////////////////

  ** Write string
  This w(Obj obj) { out.print(obj); return this }

  ** Write one char
  This wc(Int char) { out.writeChar(char); return this }

  ** Write space
  This sp() { out.writeChar(' '); return this }

  ** Write newline
  This nl() { out.printLine; return this }

  ** Write start of line indentation spaces
  This tab() { w(Str.spaces(indentation*2)) }

  ** Increment indentation by one level
  This indent() { ++indentation; return this }

  ** Decrement indentation by one level
  This unindent() { --indentation; return this }

  ** Flush underlying output stream
  This flush() { out.flush; return this }

//////////////////////////////////////////////////////////////////////////
// Options
//////////////////////////////////////////////////////////////////////////

  ** Options passed
  const Dict opts

  ** Omit spec name when using with ProjSpecs API
  Bool omitSpecName

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const LibNamespace ns     // xeto namesapce
  private OutStream out     // output stream
  private Int indentation   // indentation level
}

