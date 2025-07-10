//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Nov 2018  Brian Frank  Creation
//

using xeto

**
** DefNamespace models a symbolic namespace of defs
**
@Js
const mixin DefNamespace
{

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Timestamp when created
  @NoDoc abstract DateTime ts()

  ** Timestamp key for uniquifying cache URIs
  @NoDoc abstract Str tsKey()

//////////////////////////////////////////////////////////////////////////
// Defs
//////////////////////////////////////////////////////////////////////////

  ** Resolve def by its symbol string key
  abstract Def? def(Str symbol, Bool checked := true)

  ** Build a list of all defs in this namespace.  This call
  ** can be expensive so prefer `eachDef` or `findDefs`.
  @NoDoc abstract Def[] defs()

  ** Iterate all defs in the namespace.
  @NoDoc abstract Void eachDef(|Def| f)

  ** Iterate all defs until function returns non-null
  @NoDoc abstract Obj? eachWhileDef(|Def->Obj?| f)

  ** Find all defs which match given predicate function
  @NoDoc abstract Def[] findDefs(|Def->Bool| f)

  ** Return if any defs match given predicate function
  @NoDoc abstract Bool hasDefs(|Def->Bool| f)

  ** List features
  @NoDoc abstract Feature[] features()

  ** Lookup a feature by name
  @NoDoc abstract Feature? feature(Str name, Bool checked := true)

  ** Return if def maps to a feature
  @NoDoc abstract Bool isFeature(Def def)

  ** List libs in the scope sorted by name
  @NoDoc abstract DefLib[] libsList()

  ** Resolve lib by simple name.
  @NoDoc abstract DefLib? lib(Str name, Bool checked := true)

  ** List file types
  @NoDoc abstract Filetype[] filetypes()

  ** Lookup a file type by name key or MIME type name.
  ** If using a mime type, then use 'MimeType.noParams.toStr'.
  @NoDoc abstract Filetype? filetype(Str name, Bool checked := true)

//////////////////////////////////////////////////////////////////////////
// Fits
//////////////////////////////////////////////////////////////////////////

  ** Return if 'def' fits the given 'base' definition.  If true this
  ** means that 'def' is assignable to types of 'base'.  This is effectively
  ** the same as checking if 'inheritance(def)' contains base.
  @NoDoc abstract Bool fits(Def def, Def base)

  ** Return if def fits marker
  @NoDoc abstract Bool fitsMarker(Def def)

  ** Return if def fits value
  @NoDoc abstract Bool fitsVal(Def def)

  ** Return if def fits choice
  @NoDoc abstract Bool fitsChoice(Def def)

  ** Return if def fits entity
  @NoDoc abstract Bool fitsEntity(Def def)

  ** Map def to its best fit Kind from its inheritance hierarchy.  This
  ** method should not be used in new code, but only to shim the new def
  ** model to old code using the Kind API.  Return Kind.obj as fallback.
  @NoDoc abstract Kind defToKind(Def def)

//////////////////////////////////////////////////////////////////////////
// Reflection
//////////////////////////////////////////////////////////////////////////

  ** Return tag value of given def only if its declared and not inherited.
  @NoDoc abstract Obj? declared(Def def, Str name)

  ** Return declared supertypes of the given def.  The result
  ** is effectively the resolved defs of the "is" meta tag.
  @NoDoc abstract Def[] supertypes(Def def)

  ** Return all declared subtypes of the given def.  This is
  ** effectively all defs which have a declared supertype of def.
  ** Feature keys are not included in results.
  @NoDoc abstract Def[] subtypes(Def def)

  ** Return if the given def has subtypes.
  @NoDoc abstract Bool hasSubtypes(Def def)

  ** Return a flatten list of all supertypes of the given def.  This
  ** list always includes the def itself.   The result represents the
  ** complete set of all defs implemented by the given def.
  @NoDoc abstract Def[] inheritance(Def def)

  ** Return number of supertypes of given depth.  This is the distance
  ** from the root types (marker, val, feature).  In cases where multiple
  ** supertypes are defined, only the first one is used.
  @NoDoc abstract Int inheritanceDepth(Def def)

  ** Return list of defs for given association on the parent.
  ** Association define ontological relationships between definitions.
  @NoDoc abstract Def[] associations(Def parent, Def association)

  ** Convenience for 'associations(parent, ^tags)'
  @NoDoc abstract Def[] tags(Def parent)

  ** Match the value to one of the core kind defs
  @NoDoc abstract Def? kindDef(Obj? val, Bool checked := true)

  ** All tags which must be applied to implement given def
  @NoDoc abstract Def[] implement(Def def)

  ** Analyze the subject dict and return its implemented defs
  @NoDoc abstract Reflection reflect(Dict subject)

  ** Generate a child prototype for the given parent dict.  This call
  ** will automatically apply childrenFlatten tags and parent refs.
  @NoDoc abstract Dict proto(Dict parent, Dict proto)

  ** Generate a list of children prototypes for the given parent
  ** dict based on all its reflected defs.
  @NoDoc abstract Dict[] protos(Dict parent)

//////////////////////////////////////////////////////////////////////////
// SysNamespace (see subclass for more details)
//////////////////////////////////////////////////////////////////////////

  ** Lookup misc system data by name
  @NoDoc abstract Obj? misc(Str name, Bool checked := true)

  ** Iterate misc data values
  @NoDoc abstract Void eachMisc(|Obj,Str| f)

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Flatten all defs to a single sorted grid
  @NoDoc abstract Grid toGrid()

  ** Map symbol name to its well known URI
  @NoDoc abstract Uri symbolToUri(Str symbol)

  ** Debug dump
  @NoDoc abstract Void dump(OutStream out := Env.cur.out)
}

