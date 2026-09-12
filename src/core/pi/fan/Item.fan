//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 2023  Brian Frank  Creation
//    2 Apr 2024  Brian Frank  Repurpose DataElem
//   12 Sep 2026  Brian Frank  Move from ion
//

using util
using xeto
using haystack

**
** Item wraps a data value for presentation with text, icon, and meta.
**
@Js
const mixin Item
{
  ** Construct wrapped data:
  **  - if data is null then return [nullVal] constant
  **  - if data is Item, return it
  **  - text is normalized via [pi::Text.fromData]
  **  - if meta is data if Dict, otherwise empty dict
  **  - id/sni comes from meta or is auto-generated
  static new make(Obj? data, Icon? icon := null, Obj? text := null, Dict? meta := null)
  {
    if (data == null) return nullVal
    if (data is Item) return data
    if (data is Spec) return makeSpec(data)
    if (meta == null) meta = data as Dict ?: Etc.dict0
    t  := text != null ? Text.fromData(text) : Text.fromData(data, meta)
    if (icon == null) icon = Icon.fromDict(meta)
    return MItem(data, t, icon, meta)
  }

  ** Constant for null value
  static const Item nullVal := MItem("__null", Text.defVal, null, Etc.dict0)

  ** Constant for noData value
  @NoDoc static const Item noData := MItem("__noData", Text("$<pi::noData>"), null, Etc.dict0)

  ** Spec constructor
  @NoDoc static Item makeSpec(Spec spec) { PiEnv.cur.specItem(spec) }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Get the item id
  abstract Ref id()

  ** Get the item subject navigation identifier
  abstract Sni sni()

  ** Presentation text
  abstract Text text()

  ** Presentation icon if available
  abstract Icon? icon()

  ** Wrapped data value. Use [isNull] to check for null data
  abstract Obj data()

  ** Is this the special nullVal constant
  Bool isNull() { this === nullVal }

  ** Return if this item an subtype of ItemCollection
  virtual Bool isCollection() { false }

  ** Navigation children face if this item exposes one
  @NoDoc virtual ItemList? nav() { null }

  ** Metadata
  abstract Dict meta()

  ** Spec type for this item resolved from data
  virtual Spec spec()
  {
    ns := PiEnv.cur.ns
    ref := meta["spec"] as Ref
    if (ref != null) return ns.spec(ref.id)
    return ns.specOf(data, false) ?: PiEnv.cur.ns.spec("sys::Obj")
  }

  ** Presentation color if available
  @NoDoc virtual ColorName? color() { ColorName.coerce(meta["color"]) }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  ** Presentation text string
  virtual Str dis() { text.dis }

  ** Return text display
  override Str toStr() { text.dis }

  ** Convenience for meta.get
  @Operator virtual Obj? get(Str name) { meta.get(name) }

  ** Convenience for meta.has
  virtual Bool has(Str name) { meta.has(name) }

  ** Convenience for meta.missing
  virtual Bool missing(Str name) { meta.missing(name) }

  ** Sorting
  override final Int compare(Obj that) { PiUtil.sortCompare(this, that) }

//////////////////////////////////////////////////////////////////////////
// Dump
//////////////////////////////////////////////////////////////////////////

  ** Debug dump this item to the console
  @NoDoc virtual Void dump(Console con := Console.cur, Dict? opts := null)
  {
    doDump(con, opts)
  }

  internal virtual Void doDump(Console con, Dict opts)
  {
    con.info(dumpToStr(opts))
  }

  @NoDoc Str dumpToStr(Dict? opts:= null)
  {
    format := opts?.get("format") as Unsafe
    if (format != null) return ((Func)format.val)(this)
    s := StrBuf()
    s.add(dis)
    if (icon != null) s.add(" !").add(icon.name)
    s.add(" ").add(id.toCode)
    return s.toStr
  }
}

**************************************************************************
** MItem
**************************************************************************

**
** Standard implementation of Item
**
@NoDoc @Js
const class MItem : Item
{
  new make(Obj data, Text text, Icon? icon, Dict meta)
  {
    sniVal := meta.get("sni")
    idVal  := meta.get("id") as Ref
    if (sniVal != null && idVal != null)
    {
      this.sni = Sni.coerce(sniVal)
      this.id  = idVal
    }
    else if (sniVal != null)
    {
      this.sni = Sni.coerce(sniVal)
      this.id  = this.sni.id
    }
    else if (idVal != null)
    {
      this.id  = idVal
      this.sni = Sni.fromId(idVal, false)
    }
    else if (data is Dict)
    {
      throw ArgErr("Dict item requires id or sni")
    }
    else
    {
      this.sni = Sni.makeTemp
      this.id  = this.sni.id
    }
    this.data = data
    this.text = text
    this.icon = icon
    this.meta = meta
  }

  override const Ref id
  override const Sni sni
  override const Obj data
  override const Text text
  override const Icon? icon
  override const Dict meta
}

