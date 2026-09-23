//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2026  Brian Frank  Creation
//

using util

**
** Sugar APIs for a spec with the 'sugar' marker via [Spec.sugar]
**
@NoDoc @Js
const mixin SpecSugar
{
  ** Nominal anchor: single most specific non-sugar ancestor
  abstract Spec anchor()

  ** Effective constraint slots down the sugar chain up to the anchor
  ** sorted by name: required markers and invariant scalars.  Other
  ** slots are defaults for instantiation and never constrain
  abstract SpecMap constraints()
}

