//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 2023  Brian Frank  Creation
//    2 Apr 2024  Brian Frank  Repurpose DataSet
//

using xeto
using haystack

**
** ItemList is a simple flat list of items
**
@Js
const mixin ItemList : ItemCollection
{
  ** Empty list
  static const ItemList empty := EmptyItemList()

  ** Construct with list of objects that are coercd via Item.make
  static new makeList(Obj[] items, Item? self := null)
  {
    if (items.isEmpty && self == null) return empty
    if (!items.of.fits(Item#)) items = items.map |x->Item| { Item(x) }
    return PiEnv.cur.itemList(items, self)
  }

  ** Return if this list contains the given item by reference equality
  abstract Bool contains(Item item)

  ** Nav children face is this list
  @NoDoc override ItemList? nav() { this }
}

**************************************************************************
** EmptyItemList
**************************************************************************

**
** Immutable empty list safe for static initialization
**
@NoDoc @Js
const class EmptyItemList : ItemList
{
  override once Item self() { Item.make(Item#.emptyList, null, "0 $<pi::items>") }

  override Item[] list() { Item#.emptyList }

  override Item? itemById(Ref id, Bool checked := true)
  {
    if (checked) throw UnknownItemErr(id.toStr)
    return null
  }

  override Bool contains(Item item) { false }

  override Bool isTree() { false }

  override Bool isGrid() { false }
}

