//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 2023  Brian Frank  Creation
//    2 Apr 2024  Brian Frank  Repurpose DataSet
//

using util
using xeto
using haystack

**
** ItemCollection is a collection of items
**
@Js
const mixin ItemCollection : Item
{

//////////////////////////////////////////////////////////////////////////
// Item
//////////////////////////////////////////////////////////////////////////

  ** The identity item for this collection
  abstract Item self()

  ** Return true
  override final Bool isCollection() { true }

  ** Item.sni routes to self
  override final Sni sni() { self.sni }

  ** Item.id routes to self
  override final Ref id() { self.id }

  ** Item.data routes to self
  override final Obj data() { self.data }

  ** Item.text routes to self
  override final Text text() { self.text }

  ** Item.icon routes to self
  override final Icon? icon() { self.icon }

  ** Item.meta routes to self
  override final Dict meta() { self.meta }

  ** Presentation color if available
  @NoDoc override final ColorName? color() { self.color }

  ** Spec is always [sys::Collection]
  override final Spec spec() {PiEnv.cur.ns.spec("sys::Collection") }

  ** Nav children face as ItemList of this collection
  @NoDoc override ItemList? nav() { ItemList(list, self) }

  ** Spec type for items within this collection
  virtual Spec? of(Bool checked := true)
  {
    ofRef := self.meta["of"] as Ref
    if (ofRef != null) return PiEnv.cur.ns.spec(ofRef.toStr, checked)
    if (checked) throw UnsupportedErr("${typeof}.of")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Collection
//////////////////////////////////////////////////////////////////////////

  ** Is this collection of items that implementats ItemTree
  abstract Bool isTree()

  ** Is this collection of items that implementats ItemGrid
  abstract Bool isGrid()

  ** Backing grid if `isGrid` otherwise raise UnsupportedErr
  @NoDoc virtual Grid grid() { throw UnsupportedErr("${typeof}.grid") }

  ** List the items in this collection; for tree this lists the roots only
  abstract Item[] list()

  ** Lookup child item by id
  abstract Item? itemById(Ref id, Bool checked := true)

  ** Debug dump
  @NoDoc override Void dump(Console con := Console.cur, Dict? opts := null)
  {
    list := this.list
    con.info("=== $typeof [$list.size items] ===")
    list.each |item| { con.info(item.dumpToStr(opts as Dict)) }
  }
}

