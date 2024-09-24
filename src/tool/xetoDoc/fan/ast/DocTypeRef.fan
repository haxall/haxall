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
  ** Return qualified name (if compound "sys::And" or "sys::Or")
  abstract Str qname()

  ** Return if this is an And/Or type
  virtual Bool isCompound() { false }

  ** Compound types or null if not applicable
  virtual DocTypeRef[]? ofs() { null }

  ** Encode to a JSON object tree
  abstract Obj encode()

  ** Decode from a JSON object tree
  static DocTypeRef? decode(Obj? obj)
  {
    if (obj == null) return null
    if (obj is Str) return DocSimpleTypeRef(obj.toStr)
    map := (Str:Obj)obj
    ofs := map["and"]; if (ofs != null) return DocAndTypeRef(decodeList(ofs))
    ofs = map["or"]; if (ofs != null) return DocOrTypeRef(decodeList(ofs))
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
  ** Constructor
  new make(Str qname) { this.qname = qname }

  ** URI to this type
  Uri uri() { DocUtil.qnameToUri(qname) }

  ** Qualified name of the type
  const override Str qname

  ** Simple name of the type
  Str name() { XetoUtil.qnameToName(qname) }

  ** Encode to a JSON object tree
  override Obj encode() { qname }
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
  new make(DocTypeRef[] ofs) { this.ofs = ofs }

  ** Compound types
  override const DocTypeRef[]? ofs

  ** Return true
  override Bool isCompound() { true }
}

**
** DocAndTypeRef
**
@Js
const class DocAndTypeRef : DocCompoundTypeRef
{
  new make(DocTypeRef[] ofs) : super(ofs) {}
  override Str qname() { "sys::And" }
  override Str:Obj encode() { ["and":ofs.map |x| { x.encode}] }
}

**
** DocOrTypeRef
**
@Js
const class DocOrTypeRef : DocCompoundTypeRef
{
  new make(DocTypeRef[] ofs) : super(ofs) {}
  override Str qname() { "sys::Or" }
  override Str:Obj encode() { ["or":ofs.map |x| { x.encode}] }
}

