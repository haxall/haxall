//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Dec 2009  Brian Frank  Creation
//   16 Jan 2023  Brian Frank  Mirror in xeto pod
//    2 Jul 2025  Brian Frank  Move from haystack to xeto
//

**
** Dict is an immutable map of name/value pairs.
**
@Js
const mixin Dict
{
  ** Get the 'id' tag as a Ref or raise CastErr/UnknownNameErr
  virtual Ref id()
  {
    get("id", null) ?: throw UnknownNameErr("id")
  }

  ** Return if the there are no name/value pairs
  abstract Bool isEmpty()

  ** Get the value for the given name or 'def' if name not mapped
  @Operator abstract Obj? get(Str name, Obj? def := null)

  ** Return true if this dictionary contains given name
  abstract Bool has(Str name)

  ** Return true if this dictionary does not contain given name
  abstract Bool missing(Str name)

  ** Iterate through the name/value pairs
  abstract Void each(|Obj val, Str name| f)

  ** Iterate through the name/value pairs until the given
  ** function returns non-null, then break the iteration and
  ** return resulting object.  Return null if function returns
  ** null for every name/value pair.
  abstract Obj? eachWhile(|Obj val, Str name->Obj?| f)

  ** Get the value mapped by the given name.  If it is not
  ** mapped to a non-null value, then throw an UnknownNameErr.
  override abstract Obj? trap(Str name, Obj?[]? args := null)

  ** Create a new instance of this dict with the same names,
  ** but apply the specified closure to generate new values.
  @NoDoc virtual This map(|Obj val, Str name->Obj| f)
  {
    acc := Str:Obj[:]
    each |v, n| { acc[n] = f(v, n) }
// TODO
return Slot.findMethod("haystack::Etc.dictFromMap").call(acc)
  }

  ** Get display string for dict or the given tag.  If 'name'
  ** is null, then return display text for the entire dict
  ** using `Etc.dictToDis`.  If 'name' is non-null then format
  ** the tag value using its appropiate 'toLocale' method.  If
  ** 'name' is not defined by this dict, then return 'def'.
  virtual Str? dis(Str? name := null, Str? def := "")
  {
// TODO
    // if name is null
//    if (name == null) return Etc.dictToDis(this, def)
if (name == null) return Slot.findMethod("haystack::Etc.dictToDis").call(this, def)

    // get the value, if null return the def
    val := get(name)
    if (val == null) return def

    // fallback to Kind to get a suitable default display value
return Slot.findMethod("haystack::Kind.fromType").call(val.typeof)->valToDis(val)
  }

  ** Return string for debugging only
  //override Str toStr() { Etc.dictToStr(this) }
}

