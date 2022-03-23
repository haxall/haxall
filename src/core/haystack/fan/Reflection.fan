//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Feb 2019  Brian Frank  Creation
//

**
** Reflection is the analysis of a Dict into the list of Defs it implements
**
@NoDoc @Js
const mixin Reflection
{
  ** Source dict analyzed
  abstract Dict subject()

  ** List of def terms implemented by the subject.  This list includes all
  ** conjuncts; for example '{hot, water}', will include 'hot', 'water',
  ** and 'hot-water'.  But note these defs are the declared terms only, not
  ** the full list of all inferred tags through inheritance.  For example if
  ** subject has the 'ahu' tag, then this list does *not* automatically
  ** include the 'airHandlingEquip' tag (unless was explicitly included
  ** in the the subject dict).
  abstract Def[] defs()

  ** Return def by symbol key if implemented directly by subject.
  ** Does not take into account inferred inheritance (instead use fits).
  abstract Def? def(Str symbol, Bool checked := true)

  ** Does any of the subject's tags fit the given base def
  abstract Bool fits(Def base)

  ** Return best fit, most specific entity marker(s) for the subject.
  ** This function automatically removes supertype tags.  For example if
  ** the subject is '{rtu, ahu, equip}', then just '[rtu]' is returned.
  ** However if the subject has multiple leaf types such as '{cur, his, point}'
  ** then '[cur-point, his-point]' is returned.  If the subject does not
  ** implement any entity subtype markers then return empty list.
  abstract Def[] entityTypes()

  ** Flatten defs as grid
  abstract Grid toGrid()
}