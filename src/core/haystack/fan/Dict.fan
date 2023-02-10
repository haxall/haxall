//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Dec 2009  Brian Frank  Creation
//

**
** Dict is a map of name/value pairs.  It is used to model grid rows, grid
** meta-data, and name/value object literals.  Dict is characterized by:
**   - names must match `Etc.isTagName` rules
**   - values should be one valid Haystack kinds
**   - get '[]' access returns null if name not found
**   - trap '->' access throws exception if name not found
**
** Also see `Etc.emptyDict`, `Etc.makeDict`.
**
@Js
const mixin Dict
{
  **
  ** Return if the there are no name/value pairs
  **
  abstract Bool isEmpty()

  **
  ** Get the value for the given name or 'def' if name not mapped
  **
  @Operator
  abstract Obj? get(Str name, Obj? def := null)

  **
  ** Return true if the given name is mapped to a non-null value.
  **
  abstract Bool has(Str name)

  **
  ** Return true if the given name is not mapped to a non-null value.
  **
  abstract Bool missing(Str name)

  **
  ** Iterate through the name/value pairs
  **
  abstract Void each(|Obj val, Str name| f)

  **
  ** Iterate through the name/value pairs until the given
  ** function returns non-null, then break the iteration and
  ** return resulting object.  Return null if function returns
  ** null for every name/value pair.
  **
  abstract Obj? eachWhile(|Obj val, Str name->Obj?| f)

  **
  ** Get the value mapped by the given name.  If it is not
  ** mapped to a non-null value, then throw an UnknownNameErr.
  **
  override abstract Obj? trap(Str name, Obj?[]? args := null)

  **
  ** Get the 'id' tag as a Ref or raise CastErr/UnknownNameErr
  **
  virtual Ref id()
  {
    get("id", null) ?: throw UnknownNameErr("id")
  }

  **
  ** Get display string for dict or the given tag.  If 'name'
  ** is null, then return display text for the entire dict
  ** using `Etc.dictToDis`.  If 'name' is non-null then format
  ** the tag value using its appropiate 'toLocale' method.  If
  ** 'name' is not defined by this dict, then return 'def'.
  **
  virtual Str? dis(Str? name := null, Str? def := "")
  {
    // if name is null
    if (name == null) return Etc.dictToDis(this, def)

    // get the value, if null return the def
    val := get(name)
    if (val == null) return def

    // fallback to Kind to get a suitable default display value
    return Kind.fromType(val.typeof).valToDis(val)
  }

  ** Return string for debugging only
  override Str toStr() { Etc.dictToStr(this) }
}

