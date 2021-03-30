//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Jan 2019  Brian Frank  Creation
//

using haystack

**
** Normalize:
**  - normalize lib meta
**  - add implicit lib tag
**  - normalize associations
**  - normalizes special tags tz, unit
**
internal class Normalize : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    eachLib |lib| { normalizeLib(lib) }
    eachDef |def| { normalize(def) }
  }

  private Void normalizeLib(CLib lib)
  {
    if (lib.meta["version"] == null)
    {
      err("Lib must define version: $lib", lib.loc)
      lib.set(etc.version, "0.0")
    }
  }

  internal Void normalize(CDef def)
  {
    // some special handling
    if (def.symbol.toStr == "tz") def.set(etc.enum, TimeZone.listNames.join("\n"))
    if (def.symbol.toStr == "unit") def.set(etc.enum, tzUnitStr)

    // implied lib tag in every def
    if (def.meta["lib"] != null) err("Def cannot declare lib tag: $def", def.loc)
    else def.set(def.lib.key.feature, def.lib)

    // normalize list vals
    normalizeListVals(def)

    // normalize doc
    doc := def.meta["doc"]
    if (doc != null) def.fandoc = CFandoc(def.loc, doc.val.toStr)
  }

  private Void normalizeListVals(CDef def)
  {
    def.meta.each |pair|
    {
      if (pair.tag == null) return
      if (!pair.tag.isList) return
      if (pair.tag.has("computed")) return // skip template.tags
      if (pair.val is List) return
      pair.val =  [pair.val]
    }
  }

  private Str tzUnitStr()
  {
    s := StrBuf(16_384)
    Unit.quantities.each |q|
    {
      Unit.quantity(q).each |u|
      {
        s.add("- ").add(u.symbol).add(": ").add(u.name).add(" (").add(q).add(")\n")
      }
    }
    return s.toStr
  }
}


