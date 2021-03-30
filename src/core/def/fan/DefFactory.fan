//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Feb 2019  Brian Frank  Creation
//

using haystack

**
** DefFactory used to create MNamespace and MFeature subclasses
**
@NoDoc @Js
const class DefFactory
{
  virtual MNamespace createNamespace(BNamespace b)
  {
    MBuiltNamespace(b)
  }

  virtual MFeature createFeature(BFeature b)
  {
    switch (b.name)
    {
      case "lib":      return MLibFeature(b)
      case "filetype": return MFiletypeFeature(b)
      default:         return MFeature(b)
    }
  }
}