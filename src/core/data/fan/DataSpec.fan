//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using util

**
** Data specification.  DataSpec implements the DataDict mixin
** which models the effective meta-data (including from inherited
** types).  Use the `own` method to get only the declared meta-data.
**
@Js
const mixin DataSpec : DataDict
{

  ** Environment for spec
  abstract DataEnv env()

  ** Parent spec which contains this spec definition and scopes `name`.
  ** Returns null for libs and derived specs.
  abstract DataSpec? parent()

  ** Return simple name scoped by `parent`.  This method
  ** returns the empty string a library.
  abstract Str name()

  ** Return fully qualified name of this spec:
  **   - DataLib will return "foo.bar"
  **   - DataType will return "foo.bar::Baz"
  **   - DataType slots will return "foo.bar::Baz.qux"
  **   - Derived specs will return "derived123::{name}"
  abstract Str qname()

  ** Type of this spec.   If this spec is a DataType itself then return self.
  abstract DataType type()

  ** Base spec from which this spec directly inherits its meta and slots.
  ** Returns null if this is 'sys::Obj' itself.
  abstract DataSpec? base()

  ** Get my own declared meta-data
  abstract DataDict own()

  ** Get the declared children slots
  abstract DataSlots slotsOwn()

  ** Get the effective children slots including inherited
  abstract DataSlots slots()

  ** Convenience for 'slots.get'
  abstract DataSpec? slot(Str name, Bool checked := true)

  ** Convenience for 'slotsOwn.get'
  abstract DataSpec? slotOwn(Str name, Bool checked := true)

  ** Return if 'this' specs inherits from 'that' from a nominal type perspective.
  ** Nonimal typing matches any of the following conditions:
  **   - if 'that' matches one of 'this' inherited specs via `base`
  **   - if 'this' is maybe and that is 'None'
  **   - if 'this' is 'And' and 'that' matches any 'this.ofs'
  **   - if 'this' is 'Or' and 'that' matches all 'this.ofs' (common base)
  **   - if 'that' is 'Or' and 'this' matches any of 'that.ofs'
  abstract Bool isa(DataSpec that)

  ** Does meta have maybe tag
  abstract Bool isMaybe()

//////////////////////////////////////////////////////////////////////////
// NoDoc
//////////////////////////////////////////////////////////////////////////

  ** File location of definition or unknown
  @NoDoc abstract FileLoc loc()

  ** Is this the None type itself
  @NoDoc abstract Bool isNone()

  ** Inherits directly from 'sys::Scalar' without considering And/Or
  @NoDoc abstract Bool isScalar()

  ** Inherits directly from 'sys::Marker' without considering And/Or
  @NoDoc abstract Bool isMarker()

  ** Inherits directly from 'sys::Seq' without considering And/Or
  @NoDoc abstract Bool isSeq()

  ** Inherits directly from 'sys::Dict' without considering And/Or
  @NoDoc abstract Bool isDict()

  ** Inherits directly from 'sys::List' without considering And/Or
  @NoDoc abstract Bool isList()

  ** Inherits directly from 'sys::And' without considering And/Or
  @NoDoc abstract Bool isAnd()

  ** Inherits directly from 'sys::Or' without considering And/Or
  @NoDoc abstract Bool isOr()

  ** Inherits directly from 'sys::Query' without considering And/Or
  @NoDoc abstract Bool isQuery()

}