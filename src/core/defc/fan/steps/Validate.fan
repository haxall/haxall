//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    3 Aug 2018  Brian Frank  Creation
//    9 Jan 2019  Brian Frank  Redesign
//

using haystack

**
** Validate performs detailed error checking on all the definitions
**
internal class Validate : DefCompilerStep
{
  new make(DefCompiler c) : super(c)
  {
  }

  override Void run()
  {
    eachLib |lib| { validateLib(lib) }
    eachDef |def| { validateDef(def) }
  }

  private Void validateLib(CLib lib)
  {
    if (lib.meta["baseUri"] == null) err("Lib must define baseUri: $lib", lib.loc)
  }

  private Void validateDef(CDef def)
  {
    if (def.toStr == "index")
      err("The name 'index' is reserved for documentation", def.loc)

    if (!fitsRoot(def) && !def.type.isKey)
      err("Def must derive from one of the core base types: $def", def.loc)

    switch (def.type)
    {
      case SymbolType.conjunct: validateConjuct(def)
    }

    def.meta.each |pair| { validateDefTag(def, pair) }
  }

  private Void validateConjuct(CDef def)
  {
    def.conjunct.tags.each |tag|
    {
      if (!tag.isMarker) err("Conjunct terms must be all be markers: $tag.symbol", def.loc)
    }
  }

  private Void validateDefTag(CDef def, CPair pair)
  {
    tag := pair.tag
    if (tag == null) return
    name := tag.name

    if (tag.has("computed") && !isComputedException(def, pair))
      err("Cannot declare computed tag '$pair.name' on '$def'", def.loc)

    if (name == "tagOn" && !def.type.isTag)
      err("Cannot use tagOn on $def.symbol.type '$def'", def.loc)

    if (name == "children" && !def.isEntity)
      err("Cannot use children tag on non-entity '$def'", def.loc)

    if (name == "of")
      verifyOfTag(def, pair)

    if (tag.isChoice && pair.val !== Marker.val)
      err("Choice tag '$name' must use tagOn", def.loc)

    if (tag.isRelationship && !def.isRef)
      err("Cannot apply relationship tag '$name' to non-ref '$def'", def.loc)
  }

  private Void verifyOfTag(CDef def, CPair pair)
  {
    if (def.isChoice)
    {
      val := pair.val as CDef
      if (val != null && !val.isMarker)
        err("Choice 'of' value must be marker '$def'", def.loc)
    }
  }

  Bool fitsRoot(CDef def) { def.isMarker || def.isVal|| def.isFeature }

  Bool isComputedException(CDef def, CPair pair)
  {
    // TODO this is little ugly, but most pragmatic solution for now
    if (pair.name == "tags" && def.has("template")) return true
    return false
  }
}