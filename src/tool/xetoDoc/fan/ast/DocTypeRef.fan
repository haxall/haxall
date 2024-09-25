//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Sep 2024  Brian Frank  Creation
//

using xetoEnv

**
** DocTypeRef models the signature of a type
**
@Js
abstract const class DocTypeRef
{
  static DocTypeRef dict() { DocSimpleTypeRef.predefined.getChecked("sys::Dict") }
  static DocTypeRef list() { DocSimpleTypeRef.predefined.getChecked("sys::List") }

  ** Return qualified name (if compound "sys::And" or "sys::Or")
  abstract Str qname()

  ** Return simple name
  Str name() { XetoUtil.qnameToName(qname) }

  ** Return if this is a Maybe type
  abstract Bool isMaybe()

  ** Return if this is an And/Or type
  virtual Bool isCompound() { false }

  ** Return null, "&" or "|"
  virtual Str? compoundSymbol() { null }

  ** Compound types or null if not applicable
  virtual DocTypeRef[]? ofs() { null }

  ** Encode to a JSON object tree
  abstract Obj encode()

  ** Decode from a JSON object tree
  static DocTypeRef? decode(Obj? obj)
  {
    if (obj == null) return null
    if (obj is Str)
    {
      sig := obj.toStr
      if (sig.endsWith("?")) return DocSimpleTypeRef(sig[0..-2], true)
      return DocSimpleTypeRef(sig, false)

    }
    map := (Str:Obj)obj
    isMaybe := map["maybe"] != null
    ofs := map["and"]; if (ofs != null) return DocAndTypeRef(decodeList(ofs), isMaybe)
    ofs = map["or"]; if (ofs != null) return DocOrTypeRef(decodeList(ofs), isMaybe)
    throw Err("Cannot decode: $obj")
  }

  ** Decode list of refs
  static DocTypeRef[] decodeList(Obj[] list)
  {
    list.map |x->DocTypeRef| { decode(x) }
  }
}

**************************************************************************
** DocSimpleTypeRef
**************************************************************************

**
** DocSimpleTypeRef links to one type spec with no parameterization
**
@Js
const class DocSimpleTypeRef : DocTypeRef
{
  static const Str:DocSimpleTypeRef predefined
  static
  {
    acc := Str:DocSimpleTypeRef[:]
    add := |Str qname| { acc[qname] = DocSimpleTypeRef.doMake(qname, false) }
    add("sys::Dict")
    add("sys::Enum")
    add("sys::Func")
    add("sys::Marker")
    add("sys::Number")
    add("sys::List")
    add("sys::Str")
    predefined = acc
  }

  ** Constructor with interning
  static new make(Str qname, Bool isMaybe := false)
  {
    if (!isMaybe)
    {
      p := predefined[qname]
      if (p != null) return p
    }
    return doMake(qname, isMaybe)
  }

  ** Private constructor
  private new doMake(Str qname, Bool isMaybe)
  {
    this.qname = qname
    this.isMaybe = isMaybe
  }

  ** URI to this type
  Uri uri() { DocUtil.qnameToUri(qname) }

  ** Qualified name of the type
  const override Str qname

  ** Is this maybe type
  const override Bool isMaybe

  ** Encode to a JSON object tree
  override Obj encode()
  {
    if (isMaybe) return "${qname}?"
    return qname
  }

  ** String
  override Str toStr() { encode }
}

**************************************************************************
** DocCompoundTypeRefs
**************************************************************************

**
** DocCompoundTypeRef
**
@Js
abstract const class DocCompoundTypeRef : DocTypeRef
{
  ** Constructor
  new make(DocTypeRef[] ofs, Bool isMaybe)
  {
    this.ofs = ofs
    this.isMaybe = isMaybe
  }

  ** Compound types
  override const DocTypeRef[]? ofs

  ** Return if this is a Maybe type
  override const Bool isMaybe

  ** Return true
  override Bool isCompound() { true }

  ** Encode
  override final Str:Obj encode()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    if (isMaybe) acc["maybe"] = true
    acc[encodeTag] = ofs.map |x| { x.encode}
    return acc
  }

  ** Return "and" or "or"
  abstract Str encodeTag()

  ** String
  override Str toStr() { ofs.join(" $compoundSymbol ") }
}

**
** DocAndTypeRef
**
@Js
const class DocAndTypeRef : DocCompoundTypeRef
{
  new make(DocTypeRef[] ofs, Bool isMaybe) : super(ofs, isMaybe) {}
  override Str qname() { "sys::And" }
  override Str? compoundSymbol() { "&" }
  override Str encodeTag() { "and" }
}

**
** DocOrTypeRef
**
@Js
const class DocOrTypeRef : DocCompoundTypeRef
{
  new make(DocTypeRef[] ofs, Bool isMaybe) : super(ofs, isMaybe) {}
  override Str qname() { "sys::Or" }
  override Str? compoundSymbol() { "|" }
  override Str encodeTag() { "or" }
}

