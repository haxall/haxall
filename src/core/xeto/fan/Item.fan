//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Feb 2024  Brian Frank  Creation
//

**
** Item is a map of name/value pairs that may be mutable or immutable.
**
@Js
mixin Item
{

  // Get the 'id' tag as a Ref or raise exception
  // TODO: this can't be id yet without breaking backward binary compatibility
  abstract Ref _id()

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

  ** Set a name/value pair with the given value.  If the value
  ** is null, then this is a conveniece for remove.  If this instance
  ** is not mutable then raise ReadonlyErr.
  abstract Void set(Str name, Obj? val)

  ** Remove a slot by name. If slot is not found, then silently ignore
  ** this call. If this instanceis not mutable then raise ReadonlyErr.
  abstract Void remove(Str name)

  ** Call a method function by name.  Raise exception if name
  ** does not map to a function slot.
  virtual Obj? call(Str name, Obj?[] args) { throw UnsupportedErr() }

  ** Call a method function by name asynchronously.
  ** Invoke the given callback when the call completes with
  ** error or result.
  virtual Void callAsync(Str name, Obj?[] args, |Err?,Obj?| cb) { throw UnsupportedErr() }

}

