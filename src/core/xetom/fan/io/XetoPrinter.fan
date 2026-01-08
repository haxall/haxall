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
    this.noInferMeta = opts.has("noInferMeta")
    this.qnameForce  = opts.has("qnameForce")
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  ** Output a spec
  This spec(Spec spec)
  {
    doSpec(spec, null, null)
  }

  ** Rewrite a spec with its original state, but update the
  ** given inline meta tag (typiclaly axon/compTree).
  This updateMetaInline(Spec spec, Str name, Str val)
  {
    doSpec(spec, name, val)
  }

  ** Common code for spec/updateMetaInline
  private This doSpec(Spec spec, Str? metaName, Str? metaVal)
  {
    inlineMeta := toInlineMetaNames(spec.metaOwn).addNotNull(metaName).unique
    metaSkip := metaSkipDef.dup.addAll(inlineMeta)
    specHeader(spec.name, spec.base, spec.metaOwn, metaSkip)
    if (spec.slots.isEmpty && inlineMeta.isEmpty) return nl

    sp.w("{").nl
    indent
    spec.slotsOwn.each |x| { slot(x) }
    unindent
    inlineMeta.each |n|
    {
      v := n == metaName ? metaVal : spec.meta[n]
      nl.metaInline(n, v).nl
    }
    w("}").nl
    return this
  }

  ** Start new top-level spec or slot spec:
  **   // doc from meta
  **   name: type <meta>
  This specHeader(Str name, Obj type, Dict meta := Etc.dict0, Str[] metaSkip := metaSkipDef)
  {
    doc := meta["doc"] as Str
    if (doc != null) this.doc(doc)
    w(name).wc(':').sp
    this.type(type, meta)
    this.meta(meta, metaSkip)
    return this
  }

  ** Always skip these which should be encoded outside of meta
  static const Str[] metaSkipDef := ["ofs", "axon", "axonTree", "compTree", "doc", "maybe", "val"]

  ** Return tag names to encode as inline meta
  @NoDoc static Str[] toInlineMetaNames(Dict meta)
  {
    Etc.dictNames(meta).findAll |n| { meta[n].toStr.contains("\n") }
  }

  ** Write meta data dict. We always skip the skipMeta tags by default
  This meta(Dict meta, Str[] skip := metaSkipDef)
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
    keys.moveTo("of", 0)
    keys.moveTo("defMeta", -1)

    sp.wc('<')
    spec := ns.sys.spec
    keys.each |k, i|
    {
      if (i > 0) wc(',').sp
      dictPair(spec, k, meta[k], true)
    }
    return wc('>')
  }

  ** Encode inline meta as heredoc using current indentation
  This metaInline(Str name, Obj v)
  {
    wc('<').w(name).wc(':').sp
    if (v is Str) heredoc(v)
    else val(v, null)
    return wc('>')
  }

  ** Write a slot spec out using current indentation
  This slot(Spec slot)
  {
    tab.specHeader(slot.name, slot.type, slot.metaOwn)

    // this isn't super great until we really nail down spec vs instance slots
    subSlots := slot.slotsOwn
    if (!subSlots.isEmpty)
    {
      sp.w("{").sp
      first := true
      subSlots.each |x|
      {
        v := x.metaOwn["val"]
        if (v == null) return

        if (first) first = false
        else wc(',').sp
        dictPair(null, x.name, v, true)
      }
      sp.w("}")
    }
    nl
    return this
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
  This instance(Dict x, Str[] skip := dictSkip)
  {
    // leading id
    id := x["id"] as Ref
    if (id != null)
    {
      id = XetoUtil.qnameToName(id) ?: id
      wc('@').w(id).wc(':').sp
    }

    forceType := id == null
    dict(x, skip, forceType).nl
    return this
  }

//////////////////////////////////////////////////////////////////////////
// AST Dict
//////////////////////////////////////////////////////////////////////////

  ** Print dict AST representation of spec or instance
  This ast(Dict x)
  {
    if (x["spec"]?.toStr == "sys::Spec")
      return astSpec(x)
    else
      return astInstance(x)
  }

  ** Print AST spec representation
  This astSpec(Dict x)
  {
    name  := x["name"] as Str ?: throw Err("AST spec missing name: $x")
    type  := x["base"]?.toStr ?: "Dict"
    slots := x["slots"] as Grid

    // pull multi-line meta out for inlines
    metaInlines := Str[,]
    x.each |v, n|
    {
      if (metaSkipAst.contains(n)) return
      if (n == "defMeta" || n == "axon" || (v is Str && v.toStr.splitLines.size > 1))
        metaInlines.add(n)
    }
    metaInlines.sort
    metaInlines.moveTo("defMeta", 0)
    metaInlines.moveTo("axon", -1)
    metaInlines.moveTo("compTree", -1)

    specHeader(name, type, x, metaSkipAst.dup.addAll(metaInlines))
    if (slots == null && metaInlines.isEmpty) nl
    else
    {
      sp.w("{").nl
      indent
      if (slots != null) slots.each |s| { astSlot(s) }
      unindent
      if (!metaInlines.isEmpty)
      {
        metaInlines.each |n| { nl.metaInline(n, x[n]).nl }
      }
      w("}").nl
    }
    return this
  }

  ** Print AST slot spec representation
  This astSlot(Dict x)
  {
    name  := x["name"] as Str ?: "_0"
    type  := x["type"]?.toStr
    slots := x["slots"] as Grid
    val   := x["val"]
    maybe := x["maybe"] == Marker.val
    doc   := x["doc"] as Str
    tab
    if (doc != null) { this.doc(doc); tab }
    if (!XetoUtil.isAutoName(name)) w(name).w(": ")
    if (type != null)
    {
      w(typeName(type))
      if (maybe) w("?")
    }
    meta(x, metaSkipAst)
    if (val != null) sp.quoted(val.toStr)
    if (slots == null) nl
    else
    {
      sp.w("{").nl
      indent
      slots.each |s| { astSlot(s) }
      unindent
      tab.w("}").nl
    }
    return this
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
      if (n == "id" || n == "name" || n == "spec" || n == "rt" || n == "mod") return
      tab.dictPair(null, n, v, false).nl
    }
    unindent
    return w("}").nl
  }

  ** Always skip these which should be encoded outside of meta
  static const Str[] metaSkipAst := ["id", "mod", "rt", "name", "ofs", "base", "type", "slots", "spec", "doc", "maybe", "val"]

//////////////////////////////////////////////////////////////////////////
// AST Axon Func
//////////////////////////////////////////////////////////////////////////

  Void axon(Dict ast)
  {
    doc   := ast["doc"] as Str
    slots := ast["slots"] as Grid ?: Etc.emptyGrid
    axon  := ast["axon"] as Str ?: "null"

    if (doc != null) w("/*").nl.w(doc).nl.w("*/").nl

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
        if (first) first = false; else wc(',').sp
        axonParam(name, slot)
      }
    }
    wc(')')
    w(" => ")
    w(axon)
  }

  private Void axonParam(Str name, Dict meta)
  {
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
      if (n == "axon")  { def = v.toStr }
      else metaNames.add(n)
    }

    // name
    w(name)

    // if everything else is defaults, we are done
    if (metaNames.isEmpty && type == "sys::Obj" && maybe && def == null)
      return

    // colon type
    wc(':').sp
    w(type)
    if (maybe) wc('?')

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
        if (v != Marker.val) wc(':').quoted(v.toStr)
      }
      wc('>')
    }

    // default
    if (def != null) sp.w(def)
  }

//////////////////////////////////////////////////////////////////////////
// Literals
//////////////////////////////////////////////////////////////////////////

  ** Literal value
  This val(Obj x, Spec? inferred)
  {
    if (x is Dict) return dict(x)
    if (x is List) return list(x, inferred)
    return scalar(x, inferred)
  }

  ** Scalar
  This scalar(Obj x, Spec? inferred)
  {
    if (x is Ref) return ref(x)

    spec := specOf(x)
    if (x isnot Str && spec != inferred) type(spec, Etc.dict0).sp
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

  ** Standard dict skip tags
  static const Str[] dictSkip := ["id", "spec"]

  ** Dict value
  This dict(Dict x, Str[] skip := dictSkip, Bool forceType := false)
  {
    spec := specOf(x)
    if (spec.qname != "sys::Dict" || forceType) type(spec, Etc.dict0).sp
    wc('{')
    num := 0
    indent
    x.each |v, n|
    {
      if (skip.contains(n)) return
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
    type(spec, Etc.dict0).sp.wc('{')
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

  ** Write type name where type can be string like "Str" or a Spec
  This type(Obj type, Dict meta)
  {
    name := type is Spec ? ((Spec)type).qname : type.toStr
    if (name == "sys::And" || name == "sys::Or")
    {
      ofs := meta["ofs"] as List
      sep := name == "sys::And" ? '&' : '|'
      if (ofs != null)
      {
        ofs.each |x, i|
        {
          if (i > 0) sp.wc(sep).sp
          this.type(x, Etc.dict0)
        }
        return this
      }
    }

    w(typeName(name))
    if (meta.has("maybe")) wc('?')
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
    // TODO: cannot do this during compile; need to refactor
    // all the async loading first and simplify the MNamespace
    // if (ns.unqualifiedTypes(simple).size > 1) return n

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

  ** Don't try to infer meta from ns
  Bool noInferMeta

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns       // xeto namespace
  private OutStream out     // output stream
  private Int indentation   // indentation level
}

