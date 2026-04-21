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
  new make(MNamespace ns, OutStream out := Env.cur.out, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    this.ns   = ns
    this.out  = out
    this.opts = opts
    this.qnameForce   = opts.has("qnameForce")
    this.noDocComment = opts.has("noDocComment")
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  ** Output a spec
  This spec(Spec spec)
  {
    doSpec(XpReflectSpec(spec))
  }

  ** Common implementation for reflect Spec and AST dict
  private This doSpec(XpSpec x)
  {
    // doc
    if (x.doc != null) this.doc(x.doc)

    // name: Type <meta> "val"
    tab
    if (x.name != null) w(x.name).wc(':').sp
    if (x.type != null) type(x.type)
    metaHeader(x)
    if (x.val != null) sp.quoted(x.val)

    // if no slots or inline meta, all done
    if (!x.hasSlots && x.metaInline.isEmpty) return nl

    // { ... }
    sp.w("{").nl
    indent
    x.eachSlot |s| { doSpec(s) }
    metaInline(x)
    unindent
    tab.w("}").nl
    return this
  }

  ** Write spec meta data dict
  private Void metaHeader(XpSpec x)
  {
    if (x.metaHeader.isEmpty) return
    sp.wc('<')
    spec := ns.sys.spec
    x.metaHeader.each |n, i|
    {
      v := x.metaGet(n)
      if (i > 0) wc(',').sp
      dictPair(spec, n, v, true)
    }
    wc('>')
  }

  ** Encode inline meta as heredoc using current indentation
  private Void metaInline(XpSpec x)
  {
    x.metaInline.each |n|
    {
      v := x.metaGet(n)
      tab.wc('<').w(n).wc(':').sp
      if (v is Str) heredoc(v)
      else val(v, null)
      wc('>').nl
    }
  }

//////////////////////////////////////////////////////////////////////////
// Instance Data
//////////////////////////////////////////////////////////////////////////

  ** Top level for Namespace.writeData
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
      val(top, null)
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
  This instance(Dict x)
  {
    // leading id
    id := x["id"] as Ref
    if (id != null)
    {
      id = XetoUtil.qnameToName(id) ?: id
      wc('@').w(id).wc(':').sp
    }

    forceType := id == null
    dict(x, forceType).nl
    return this
  }

//////////////////////////////////////////////////////////////////////////
// AST Dict
//////////////////////////////////////////////////////////////////////////

  ** Print dict AST representation of spec or instance
  This ast(Dict ast)
  {
    if (ast["spec"]?.toStr == "sys::Spec")
      return astSpec(ast)
    else
      return astInstance(ast)
  }

  ** Print AST spec representation
  This astSpec(Dict ast)
  {
    doSpec(XpAstSpec(ast, true))
  }

  ** Print AST instance representation
  This astInstance(Dict x)
  {
    name := x["name"] as Str ?: throw Err("AST instance missing name: $x")
    type := x["spec"]?.toStr
    w("@").w(name).w(": ")
    if (type != null) w(type).sp
    w("{").nl
    indent
    x.each |v, n|
    {
      if (skipInst.containsKey(n)) return
      tab.dictPair(null, n, v, false).nl
    }
    unindent
    return w("}").nl
  }

//////////////////////////////////////////////////////////////////////////
// AST Axon Func
//////////////////////////////////////////////////////////////////////////

  ** Print axon source code from AST representation
  Void axon(Dict ast)
  {
    doc   := ast["doc"] as Str
    slots := ast["slots"] as Grid ?: Etc.emptyGrid
    axon  := ast["axon"] as Str ?: "null"

    if (doc != null) w("/*").nl.w(doc).nl.w("*/").nl

    // first check if any param/returns has meta, in which
    // case we format parameters with newline
    hasMeta := slots.any |s| { axonParam(s->name, s, true) }

    wc('(')
    Dict? returns
    first := true
    slots.each |slot|
    {
      name := slot->name
      if (name == "returns")
      {
        returns = slot
      }
      else
      {
        if (first) first = false
        else wc(',').sp
        if (hasMeta) nl.w("  ")
        axonParam(name, slot)
      }
    }
    if (hasMeta) nl
    wc(')')
    if (returns != null) axonParam("returns", returns)
    w(" => ").nl
    w(axon)
  }

  private Bool axonParam(Str name, Dict meta, Bool checkHasMeta := false)
  {
    isReturn := name == "returns"
    type := "sys::Obj"
    maybe := false
    Str? def := null
    metaNames := Str[,]

    // walk meta and extra specials
    meta.each |v, n|
    {
      if (n == "name") return
      if (n == "type")  { type = v.toStr; return }
      if (n == "maybe") { maybe = true; return }
      if (n == "axon" && !isReturn) { def = v.toStr; return }
      metaNames.add(n)
    }

    // the checkHasMeta flag is used to just to reuse the
    // meta logic to see if we need a <> section
    hasMeta := !metaNames.isEmpty
    if (checkHasMeta) return hasMeta

    // name
    if (!isReturn) w(name)

    // if everything else is defaults, we are done
    needType := !metaNames.isEmpty || type != "sys::Obj" || !maybe
    if (!needType && def == null)
      return hasMeta

    // colon type <meta> def
    wc(':').sp
    if (needType)
    {
      w(typeName(type))
      if (maybe) wc('?')
    }

    // meta
    if (!metaNames.isEmpty)
    {
      sp.wc('<')
      first := true
      metaNames.each |n|
      {
        if (first) first = false; else wc(',').sp
        v := meta[n]
        w(n)
        if (v != Marker.val) wc(':').axonParamMetaVal(v)
      }
      wc('>')
    }

    // default
    if (def != null)
    {
      if (needType) sp
      w(def)
    }
    return hasMeta
  }

  private Void axonParamMetaVal(Obj v)
  {
    if (v is Ref && v.toStr.contains("::"))
      w(v.toStr)
    else
      quoted(v)
  }

//////////////////////////////////////////////////////////////////////////
// Literals
//////////////////////////////////////////////////////////////////////////

  ** Literal value
  This val(Obj x, Spec? inferred)
  {
    if (x is Dict) return dict(x)
    if (x is List) return list(x, inferred)
    if (x is Grid) return list(((Grid)x).toRows, null) // TODO: how to handle?
    return scalar(x, inferred)
  }

  ** Scalar
  This scalar(Obj x, Spec? inferred)
  {
    if (x is Ref) return ref(x)

    spec := specOf(x)
    if (x isnot Str && spec != inferred) type(XpTypeRef(spec)).sp
    str := spec.binding.encodeScalar(x)
    if (str.contains("\n")) indent.heredoc(str).unindent
    else quoted(str)
    return this
  }

  ** Ref scalar
  This ref(Ref x)
  {
    // we don't use @foo::Bar for types
    colons := x.id.index("::")
    isType := colons != null && x.id[colons+2].isUpper

    if (isType)
    {
      w(x.id)
    }
    else
    {
      wc('@')
      w(x.id)
      if (x.disVal != null) sp.quoted(x.disVal)
    }
    return this
  }

  ** Dict value
  This dict(Dict x, Bool forceType := false)
  {
    spec := specOf(x)
    if (spec.qname != "sys::Dict" || forceType) type(XpTypeRef(spec)).sp
    wc('{')
    num := 0
    indent
    x.each |v, n|
    {
      if (skipDict.containsKey(n)) return
      num++
      nl.tab.dictPair(spec, n, v, false)
    }
    unindent
    if (num > 0) nl.tab
    return wc('}')
  }

  ** List value
  This list(List list, Spec? inferred)
  {
    spec := inferred ?: specOf(list)
    type(XpTypeRef(spec)).sp.wc('{')
    num := 0
    indent
    list.each |v|
    {
      num++
      nl.tab.dictPair(spec, "_0", v, false) // force use of fixed auto-name
    }
    unindent
    if (num > 0) nl.tab
    return wc('}')
  }

  ** Dict pair, inferFrom is null if meta
  This dictPair(Spec? inferFrom, Str? n, Obj v, Bool inline)
  {
    // name only
    if (isMarker(v)) return w(n)

    // determine if we have an inferred type
    Spec? infer
    if (inferFrom != null)
    {
      infer = inferFrom.member(n, false)?.type
    }

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
    if (needColon) { wc(':'); if (!inline) sp }

    return val(v, infer)
  }

//////////////////////////////////////////////////////////////////////////
// Grammar Utils
//////////////////////////////////////////////////////////////////////////

  ** Write doc lines as // comments
  private This doc(Str? str)
  {
    str = str?.trimToNull
    if (str == null) return this
    if (noDocComment) return this
    str.eachLine |line|
    {
      tab.w("//")
      if (!line.trim.isEmpty) sp.w(line.trimEnd)
      nl
    }
    return this
  }

  ** Write type reference with maybe and compound type support
  private This type(XpTypeRef x)
  {
    // handle and/or compound type
    if (x.isCompound)
    {
      sep := x.isAnd ? '&' : '|'
      x.ofs.each |of, i|
      {
        if (i > 0) sp.wc(sep).sp
        this.type(of)
      }
      return this
    }

    // qname or simple name
    if (qnameForce || ns.unqualifiedTypes(x.name).size > 1)
      w(x.qname)
    else
      w(x.name)

    // maybe
    if (x.maybe) wc('?')
    return this
  }

  ** Relative qnames unless qnameForce is set
  Str typeName(Str n)
  {
    // if flag is set
    if (qnameForce) return n

    // if not a qname
    colons := n.index("::")
    if (colons == null) return n

    // split
    simple := n[colons+2..-1]

    // if multiple matches stick with qname
    if (ns.unqualifiedTypes(simple).size > 1) return n

    // use simple name
    return simple
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

  private Bool isScalar(Obj v) { v isnot Dict && v isnot List }

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

  ** Force qnames
  Bool qnameForce

  ** Don't output doc comment
  Bool noDocComment

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Standard dict skip tags
  static const Str:Str skipDict := Str:Str[:].setList(["id", "spec"])

  ** Always skip these which should be encoded outside of meta
  static const Str:Str skipInst := Str:Str[:].setList(["id", "name", "spec", "rt", "mod"])

  ** Always skip these which should be encoded outside of meta
  static const Str:Str skipMeta := Str:Str[:].setList(["id", "name", "spec", "rt", "mod", "ofs", "base", "type", "slots", "maybe"])

  const MNamespace ns       // xeto namespace
  private OutStream out     // output stream
  private Int indentation   // indentation level
}

**************************************************************************
** XpSpec
**************************************************************************

**
** XetoPrinter spec representation - handles both reflect Spec and AST dict
**
@Js
internal abstract const class XpSpec
{
  new make(Str? name, XpTypeRef? type, Dict metaOwn)
  {
    if (name != null && XetoUtil.isAutoName(name)) name = null

    this.name    = name
    this.type    = type
    this.metaOwn = metaOwn

    if (metaOwn.isEmpty) return

    header := Str[,]
    inline := Str[,]

    metaOwn.each |v, n|
    {
      // skip meta we handle specially
      if (XetoPrinter.skipMeta.containsKey(n)) return
      if (n == "doc") { this.doc = v.toStr; return }
      if (n == "val" && isScalar(v)) { this.val = v.toStr; return }

      // check if we should inline it
      if (isMetaInline(v))
        inline.add(n)
      else
        header.add(n)
    }

    // put header keys in nice order
    if (!header.isEmpty)
    {
      header.sort
      header.moveTo("su", 0)
      header.moveTo("admin", 0)
      header.moveTo("nodoc", 0)
      header.moveTo("of", 0)
      this.metaHeader = header
    }

    // put inline keys in nice order
    if (!inline.isEmpty)
    {
      inline.sort
      this.metaInline = inline
    }
  }

  abstract Bool hasSlots()

  abstract Void eachSlot(|XpSpec| f)

  Obj metaGet(Str n) { metaOwn.get(n) ?: throw Err("Missing meta: $n") }

  private static Bool isMetaInline(Obj v)
  {
    if (isScalar(v)) return v.toStr.contains("\n")
    return false
  }

  private static Bool isScalar(Obj v) { v isnot Dict && v isnot List }

  private static const Str[] noMeta := Str[,]

  const Str? name                   // type name / slot name (null for autoName)
  const XpTypeRef? type             // type base / slot type (null for sys::Obj or inferred)
  const Dict metaOwn                // metaOwn
  const Str[] metaHeader := noMeta  // metaOwn to encode in header (excludes maybe, ofs, doc, val)
  const Str[] metaInline := noMeta  // metaOwn to encode in body inline
  const Str? doc                    // metaOwn doc tag (not inherited)
  const Str? val                    // metaOwn scalar value (not inherited)
}

**************************************************************************
** XpReflectSpec
**************************************************************************

@Js
internal const class XpReflectSpec : XpSpec
{
  new make(Spec spec) : super(spec.name, toType(spec), spec.metaOwn)
  {
    this.spec = spec
  }

  private static XpTypeRef? toType(Spec spec)
  {
    if (spec.flavor.isMember) return XpTypeRef.makeSpec(spec)
    if (spec.base != null) return XpTypeRef.makeSpec(spec.base)
    return null // sys::Obj
  }

  const Spec spec

  override Bool hasSlots() { !spec.slotsOwn.isEmpty }

  override Void eachSlot(|XpSpec| f) { spec.slotsOwn.each |s| { f(XpReflectSpec(s)) } }
}

**************************************************************************
** XpAstSpec
**************************************************************************

@Js
internal const class XpAstSpec : XpSpec
{
  new make(Dict ast, Bool top)
    : super(ast["name"], toType(ast, top), ast)
  {
    this.slots = ast["slots"] as Grid
  }

  private static XpTypeRef? toType(Dict ast, Bool top)
  {
    id := ast[top ? "base" : "type"]
    if (id == null) return null
    return XpTypeRef.makeId(id, ast)
  }

  override Bool hasSlots() { slots != null && !slots.isEmpty }

  override Void eachSlot(|XpSpec| f) { slots.each |s| { f(XpAstSpec(s, false)) } }

  const Grid? slots
}

**************************************************************************
** XpTypeRef
**************************************************************************

**
** XetoPrinter type ref representation
**
@Js
internal const class XpTypeRef
{
  new makeSpec(Spec spec)
  {
    type := spec.type
    this.id    = type.id
    this.lib   = type.lib.name
    this.name  = type.name
    this.maybe = spec.flavor.isMember && spec.meta["maybe"] == Marker.val
    this.ofs   = spec.ofs(false)?.map |x->XpTypeRef| { makeSpec(x) }
  }

  new makeId(Ref id, Dict meta)
  {
    s := id.id
    colons := s.index("::") ?: throw Err("Not type qname: $id")
    this.id    = id
    this.lib   = s[0..<colons]
    this.name  = s[colons+2..-1]
    this.maybe = meta["maybe"] == Marker.val
    this.ofs   = (meta["ofs"] as List)?.map |x->XpTypeRef| { makeId(x, Etc.dict0) }
  }

  const Ref id               // qualified name as id
  Str qname() { id.id }      // qualified name
  const Str lib              // library name
  const Str name             // simple name
  const Bool maybe           // maybe type
  const XpTypeRef[]? ofs     // meta ofs for And/Or type

  Bool isCompound() { (isAnd || isOr) && ofs != null}
  Bool isAnd() { qname == "sys::And" }
  Bool isOr() { qname == "sys::Or" }
}

