//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Sep 2026  Brian Frank  Creation
//

using xeto
using haystack

**
** EnumItems is an ordered collection of `EnumItem` modeling an
** enumeration.  It is the single model for the `enum` tag in every
** shape that tag is allowed to take.  Construct via `PiEnv.enum`.
**
@Js
const mixin EnumItems : ItemList
{
  ** Empty enumeration
  static const EnumItems none := EmptyEnumItems.val

  ** Items of this enumeration
  abstract override EnumItem[] list()

  ** Lookup an item by its string key
  abstract EnumItem? item(Str key, Bool checked := true)

  ** List the string keys in order
  abstract Str[] keys()

  ** Return if this enumeration has no items
  abstract Bool isEmpty()

  ** Lookup the item for a data value.  A Str matches by key; a Bool
  ** selects by ordinal so a two item enum can range a Bool as
  ** "false,true".  Returns null if there is no match.
  abstract EnumItem? itemForData(Obj? data)

  ** Formatter which displays a value using its item text
  abstract Format format()

  ** The encoding this enumeration was parsed from.  Parsing is
  ** lossy - "a, b" and "a\nb" yield identical items - so this is
  ** sniffed from the raw value rather than derived from the items.
  @NoDoc abstract EnumEncoding encoding()

  ** Comma separated keys
  override Str toStr() { keys.join(", ") }
}

**************************************************************************
** EnumItem
**************************************************************************

**
** EnumItem is one key of an `EnumItems`.  It is an `Item` so its
** display text, icon, color, and meta work anywhere items are
** rendered.
**
@Js
const mixin EnumItem : Item
{
  ** The enumerated key.  This is the value stored in a record, and
  ** may contain arbitrary characters when mapping to an external
  ** enumeration - use this, not `id`, as the value.
  abstract Str key()

  ** Documentation for this key or null.  Never inherited: an item
  ** without its own doc reports null rather than its enum type's.
  abstract Str? doc()
}

**************************************************************************
** EnumEncoding
**************************************************************************

**
** EnumEncoding is the wire shape of a raw `enum` tag value.  Parsing
** is lossy - "a, b" and "a\nb" yield identical items - so the shape
** is sniffed from the raw value and carried alongside.
**
@NoDoc @Js
enum class EnumEncoding
{
  ** Comma separated keys on one line
  comma,

  ** One key per line
  newline,

  ** List of key strings
  list,

  ** Markdown list of "- key: doc" lines
  markdown,

  ** Dict of dicts keyed by name
  dict,

  ** Ref to a Xeto sys::Enum spec
  ref
}

**************************************************************************
** EmptyEnumItems
**************************************************************************

** Immutable empty enum safe for static initialization
@NoDoc @Js
const class EmptyEnumItems : EnumItems
{
  static const EmptyEnumItems val := EmptyEnumItems()

  override once Item self() { Item.make(Item#.emptyList, null, "0 $<pi::items>") }
  override EnumItem[] list() { EnumItem#.emptyList }
  override EnumItem? item(Str key, Bool checked := true)
  {
    if (checked) throw UnknownNameErr(key)
    return null
  }
  override Str[] keys() { Str#.emptyList }
  override Bool isEmpty() { true }
  override EnumItem? itemForData(Obj? data) { null }
  override Format format() { Format.defVal }
  override EnumEncoding encoding() { EnumEncoding.comma }
  override Item? itemById(Ref id, Bool checked := true)
  {
    if (checked) throw UnknownItemErr(id.toStr)
    return null
  }
  override Bool contains(Item item) { false }
  override Bool isTree() { false }
  override Bool isGrid() { false }
}

