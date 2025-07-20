//
// Copyright (c) 2023, Brian Frank
// All Rights Reserved
//
// History:
//   26 Mar 2023  Brian Frank  Creation
//

/*
**
** Name table maps interned string names to/from integer codes.
** Zero is reserved for unmapped and empty string is mapped to one.
**
@NoDoc @Js
native final const class NameTable
{
  ** Return true once set has been called
  Bool isSparse()

  ** Number of names in table.
  ** If set has been used then the table may be sparse.
  Int size()

  ** Size we initialize table with predefined names
  static Int initSize()

  ** Last name code in use (inclusive).
  ** This is always the same as size, and will not be reliable
  ** if set has been used to create a sparse name table.
  Int maxCode()

  ** Map name to a code or return 0 if not mapped
  Int toCode(Str name)

  ** Map code to name or raise exception if not mapped
  Str toName(Int code)

  ** Get code for name or add to table if not mapped yet.
  ** Raise exception if set has been called and table is sparse.
  Int add(Str name)

  ** Set specific name code.  Once called isSparse is true.
  Void set(Int code, Str name)

  ** Debug dump
  Void dump(OutStream out)

  ** Create dict with one name/value pair mapped by this name table
  NameDict dict1(Str n0, Obj v0, Spec? spec := null)

  ** Create dict with two name/value pairs mapped by this name table
  NameDict dict2(Str n0, Obj v0, Str n1, Obj v1, Spec? spec := null)

  ** Create dict with three name/value pairs mapped by this name table
  NameDict dict3(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2)

  ** Create dict with four name/value pairs mapped by this name table
  NameDict dict4(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3)

  ** Create dict with five name/value pairs mapped by this name table
  NameDict dict5(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4)

  ** Create dict with six name/value pairs mapped by this name table
  NameDict dict6(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4, Str n5, Obj v5)

  ** Create dict with seven name/value pairs mapped by this name table
  NameDict dict7(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4, Str n5, Obj v5, Str n6, Obj v6)

  ** Create dict with eight name/value pairs mapped by this name table
  NameDict dict8(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4, Str n5, Obj v5, Str n6, Obj v6, Str n7, Obj v7)

  ** Create dict mapped by this name table using map
  NameDict dictMap(Str:Obj map)

  ** Wrap dict as a name dict backed by this name table
  NameDict dictDict(Dict dictl)

  ** Decode name dict from binary encoding
  NameDict readDict(Int size, NameDictReader r)
}
*/

