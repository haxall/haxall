//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Aug 2022  Brian Frank  Creation
//   22 Mar 2023  Brian Frank  Refactor from original design
//

using util
using xeto
using haystack
using haystack::Lib
using def
using defc
using xetoEnv

internal class GenPH : AbstractGenCmd
{
  override Str name() { "gen-ph" }

  override Str summary() { "Generate Xeto ph lib source code from Haystack 4 defs" }

  @Opt { help = "Directory to output" }
  override File outDir := (Env.cur.workDir + `../xeto/src/xeto/ph/`).normalize

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    checkInputs
    compileNamespace
    writeLib
    writeTags
    writeEntities
    writeEnums
    writeChoices
    writeFeatureDefs
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Check Inputs
//////////////////////////////////////////////////////////////////////////

  private Void checkInputs()
  {
    // sanity check outDir already has some files
    if (!outDir.plus(`kinds.xeto`).exists) throw Err("Invalid outDir: $outDir")
  }

//////////////////////////////////////////////////////////////////////////
// Compile Namespace
//////////////////////////////////////////////////////////////////////////

  private Void compileNamespace()
  {
    this.ns = DefCompiler().compileNamespace
    this.ph = ns.lib("ph")
  }

//////////////////////////////////////////////////////////////////////////
// Write Lib
//////////////////////////////////////////////////////////////////////////

  private Void writeLib()
  {
    write(`lib.xeto`) |out|
    {
      out.printLine(
       """pragma: Lib <
            doc: "Project haystack core library"
            version: "0.1.1"
            depends: {
              { lib: "sys", versions: "0.1.x" }
            }
            org: {
             dis: "Project Haystack"
             uri: "https://project-haystack.org/"
            }
          >""")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Write Tags
//////////////////////////////////////////////////////////////////////////

  private Void writeTags()
  {
    // get all the tags (skip abstract choice like liquid)
    tags := Def[,]
    ns.eachDef |def|
    {
      if (def.symbol.type.isTag)
        tags.add(def)
    }
    tags.sort |a, b| { a.name <=> b.name }

    write(`tags.xeto`) |out|
    {
      tags.each |def|
      {
        name := def.name
        kind := ns.defToKind(def)
        type := toTagType(def)
        meta := toTagMeta(def, kind)

        if (excludeTag(def, kind)) return

        writeDoc(out, def)
        out.printLine("$name: $type $meta".trim)
        out.printLine
      }
    }
  }

  private Bool excludeTag(Def def, Kind kind)
  {
    // skip marker, str, list, etc
    n := def.name
    if (n == kind.name.decapitalize) return true

    if (n == "doc") return true
    if (n == "is") return true
    if (n == "mandatory") return true
    if (n == "notInherited") return true
    if (n == "tagOn") return true
    if (n == "transient") return true
    if (n == "depends") return true

    // relationships
    if (n == "relationship") return true
    if (n == "inputs") return true
    if (n == "outputs") return true
    if (n == "contains") return true
    if (n == "containedBy") return true

    // associations
    if (n == "association") return true
    if (n == "quantities") return true
    if (n == "quantityOf") return true
    if (n == "tagOn") return true
    if (n == "tags") return true

    // don't generate tags like fluid, liquid
    if (isAbstract(def.name)) return true

    // don't generate direct choices such as a ductSection
    if (ns.supertypes(def).first?.name == "choice") return true

    return false
  }

  private const Symbol defSymbol := Symbol("def")

  private Str toTagType(Def tag)
  {
    if (tag.has("enum") && ns.fits(tag, ns.def("str")))
    {
      return toEnumTypeName(tag)
    }
    if (tag.name.endsWith("Ref") && multiRefs.contains(tag.name))
    {
      return "MultiRef"
    }
    if (tag.has("inputs"))
    {
      return "MultiRef"
    }
    if (tag.name == "version") return "Version"
    if (tag.name == "yearBuilt") return "Int"
    return ns.defToKind(tag).name
  }

  private once Str[] multiRefs()
  {
    ["systemRef"].toImmutable
  }

  private Str toEnumTypeName(Def tag)
  {
    if (tag.name == "tz")          return "TimeZone"
    if (tag.name == "weatherCond") return "WeatherCondEnum"
    if (tag.name == "daytime")     return "WeatherDaytimeEnum"
    return tag.name.capitalize
  }

  private Str toChoiceTypeName(Def def)
  {
    simplify := choiceSimplify(def)
    if (simplify != null) return simplify
    return XetoUtil.dottedToCamel(def.name, '-').capitalize
  }

  private Str toTagMeta(Def def, Kind kind)
  {
    if (kind.isList)
    {
      of := def["of"]
      if (of != null)
      {
        ofName := of.toStr.capitalize
        if (ofName == "Unit") ofName = "Str"
        if (ofName == "Phenomenon") return ""
        if (ofName == "MlVarRef") ofName = "Ref<of:MlVar>"
        return "<of:$ofName>"
      }
    }
    if (def.name == "area") return """<quantity:"area">"""
    if (kind.isRef)
    {
      of := def["of"]?.toStr
      if (of != null && !of.endsWith("-output"))
        return "<of:" + XetoUtil.dottedToCamel(of.toStr, '-').capitalize + ">"
    }
    if (def.has("transient"))
    {
      return "<transient>"
    }
    return ""
  }

//////////////////////////////////////////////////////////////////////////
// Write Entities
//////////////////////////////////////////////////////////////////////////

  private Void writeEntities()
  {
    // get all the entity defs
    entityDef := ns.def("entity")
    entities := ns.findDefs |def| { ns.fits(def, entityDef) }
    entities.add(ns.def("geoPlace"))
    entities.sort |a, b| { a.name <=> b.name }
    entities.removeSame(entityDef)

    write(`entities.xeto`) |out|
    {
      entities.each |def|
      {
        if (excludeEntity(def)) return
        writeDoc(out, def)
        name := toEntityName(def)
        type := toEntityType(def)
        out.print("$name: $type")
        writeEntityMeta(out, def)
        out.printLine(" {")
        writeEntityUsage(out, def)
        writeEntitySlots(out, def)
        out.printLine("}")
        out.printLine
      }
    }
  }

  private Str toEntityName(Def def)
  {
    symbol := def.symbol
    if (symbol.type.isTag) return def.name.capitalize

    s := StrBuf()
    def.symbol.eachPart |n|
    {
      s.add(n.capitalize)
    }
    return s.toStr
  }

  private Str toEntityType(Def def)
  {
    if (def.name == "entity") return "Dict"
    if (def.name == "geoPlace") return "Entity"
    if (def.name == "site") return "GeoPlace"
    if (def.name == "weatherStation") return "GeoPlace"
    supers := def["is"] as Symbol[]
    return toEntityName(ns.def(supers.first.toStr))
  }

  private Void writeEntityMeta(OutStream out, Def entity)
  {
    symbol := entity.symbol
    name := symbol.name

    // make space/equip/point abstract
    special := name == "space" || name == "equip" || name == "point" || name.endsWith("-point") || name == "geoPlace"

    if (!isAbstract(name) && !special) return

    out.print(" <abstract>")
  }

  private Void writeEntityUsage(OutStream out, Def entity)
  {
    symbol := entity.symbol
    name := symbol.name

    if (isAbstract(name)) return

    if (name == "geoPlace") return

    if (symbol.type.isTag)
    {
      // simple name
      out.printLine("  $symbol")
      return
    }
    else
    {
      // conjunct (but only entity tags we don't inherit)
      bases := ns.supertypes(entity).findAll |x| { ns.fits(x, ns.def("entity")) }
      symbol.eachPart |part|
      {
        if (bases.any { it.symbol.hasTermName(part) }) return
        out.printLine("  $part")
      }
    }
  }

  private Bool excludeEntity(Def def)
  {
    def.name == "pointGroup" || ns.supertypes(def).first.name == "pointGroup"
  }

  private Bool isAbstract(Str name)
  {
    // not sure how to best handle this, but for now just
    // consider these tags as abstract
    name == "airHandlingEquip" ||
    name == "airTerminalUnit" ||
    name == "conduit" ||
    name == "coil" ||
    name == "entity" ||
    name == "radiantEquip" ||
    name == "verticalTransport" ||

    name == "pointGroup" ||
    name == "hvacZonePoints" ||
    name == "lightingZonePoints" ||
    name == "airQualityZonePoints" ||

    name == "phenomenon" ||
    name == "quantity"   ||
    name == "substance"  ||
    name == "fluid"      ||
    name == "liquid"     ||
    name == "gas"        ||
    name == "airQuality"
  }

  private Void writeEntitySlots(OutStream out, Def entity)
  {
    tags := Def[,]
    maxNameSize := 2
    if (entity.name == "equip") maxNameSize = "parentEquips".size
    ns.tags(entity).each |tag|
    {
      if (isInherited(entity, tag)) return
      tags.add(tag)
      maxNameSize = maxNameSize.max(tag.name.size)
    }

    tags.sort |a, b| { a.name <=> b.name }

    tags.each |tag|
    {
      writeEntitySlot(out, tag.name, maxNameSize, toSlotType(entity, tag))
    }


    // built-in queries
    if (entity.name == "equip") writeEntitySlot(out, "parentEquips", maxNameSize, "Query<of:Point, via:\"equipRef+\">                  // Parent equips that contain this point")
    if (entity.name == "equip") writeEntitySlot(out, "childEquips",  maxNameSize, "Query<of:Point, inverse:\"ph::Equip.parentEquips\"> // Sub-equips contained by this equip")
    if (entity.name == "equip") writeEntitySlot(out, "points",       maxNameSize, "Query<of:Point, inverse:\"ph::Point.equips\">       // Points contained by this equip")
    if (entity.name == "point") writeEntitySlot(out, "equips",       maxNameSize, "Query<of:Equip, via:\"equipRef+\">  // Parent equips that contain this point")
  }

  private Str toSlotType(Def entity, Def tag)
  {
    type := toTagType(tag)
    if (ns.fitsChoice(tag)) type = toChoiceTypeName(tag)
    if (isOptional(entity, tag)) type += "?"
    if (entity.name == "airHandlingEquip")
    {
      if (tag.name == "heatingProcess" || tag.name == "coolingProcess") type += " <multiChoice>"
    }
    return type
  }

  private Void writeEntitySlot(OutStream out, Str name, Int maxNameSize, Str sig)
  {
    out.printLine("  $name: " + Str.spaces(maxNameSize-name.toStr.size) + sig)
  }

  private Bool isOptional(Def entity, Def tag)
  {
    if (tag.name == "id") return false

    if (entity.name == "point")
    {
      if (tag.name == "kind") return false
      return true
    }

    if (tag.name == "siteRef") return false


    return true
  }

  private Bool isInherited(Def entity, Def tag)
  {
    on := tag["tagOn"] as Symbol[]
    return !on.contains(entity.symbol)
  }

//////////////////////////////////////////////////////////////////////////
// Write Enums
//////////////////////////////////////////////////////////////////////////

  private Void writeEnums()
  {
    // get all the enums
    enums := Def[,]
    ns.eachDef |def|
    {
      if (def.missing("enum")) return
      if (def.name == "tz" || def.name =="unit") return
      if (!def.symbol.type.isTag) return
      enums.add(def)
    }
    enums.sort |a, b| { toEnumTypeName(a) <=> toEnumTypeName(b) }

    write(`enums.xeto`) |out|
    {
      enums.each |def|
      {
        writeEnum(out, def)
      }
    }
  }

  private Void writeEnum(OutStream out, Def def)
  {
    docAbove := false
    nameAndMetas := Str[,]
    docs := Str[,]
    maxNameAndMetaSize := 2
    DefUtil.parseEnum(def["enum"]).each |item|
    {
      name := (Str)item->name
      nameAndMeta := name

      if (!Etc.isTagName(name))
        nameAndMeta = normEnumName(name) + " <key:$name.toCode>"

      doc := item["doc"] as Str ?: ""
      if (doc.contains("\n")) docAbove = true

      nameAndMetas.add(nameAndMeta)
      docs.add(doc)
      maxNameAndMetaSize = maxNameAndMetaSize.max(nameAndMeta.size)
    }

    writeDoc(out, def)
    name := toEnumTypeName(def)
    out.printLine("$name: Enum {")
    nameAndMetas.each |nameAndMeta, i|
    {
      doc := docs[i]

      if (!doc.isEmpty && docAbove)
        doc.splitLines.each |line| { out.printLine("  // $line".trimEnd) }

      out.print("  $nameAndMeta")

      if (!doc.isEmpty && !docAbove)
        out.print(Str.spaces(maxNameAndMetaSize-nameAndMeta.toStr.size)).print("  // ").print(doc)

      out.printLine

      if (docAbove && i+1 < nameAndMetas.size) out.printLine
    }
    out.printLine("}")
    out.printLine
  }

//////////////////////////////////////////////////////////////////////////
// Write Choices
//////////////////////////////////////////////////////////////////////////

  private Void writeChoices()
  {
    // get all the choices
    choices := ns.subtypes(ns.def("choice"))
    choices.sort |a, b| { a.name <=> b.name }

    write(`choices.xeto`) |out|
    {
      choices.each |def|
      {
        writeChoice(out, def)
      }
    }

    // special handling for phenomenon and quantity
    writeChoiceTaxonomy(ns.def("phenomenon"))
    writeChoiceTaxonomy(ns.def("quantity"))
  }

  private Void writeChoice(OutStream out, Def def)
  {
    // skip choices that used of like pipeFluid
    if (choiceSimplify(def) != null) return

    specName := toChoiceTypeName(def)
    baseName := "Choice"

    section := "//////////////////////////////////////////////////////////////////////////"
    out.printLine(section)
    out.printLine("// $specName")
    out.printLine(section)
    out.printLine

    // handle of thru subtyping
    of := def["of"]
    if (of != null) baseName = toChoiceTypeName(ns.def(of.toStr))

    writeDoc(out, def)
    out.printLine("$specName: $baseName")
    out.printLine

    if (of != null) return

    subtypes(def).each |sub|
    {
      writeChoiceItem(out, specName, sub)
    }
  }

  private Void writeChoiceItem(OutStream out, Str base, Def x)
  {
    tag := x.symbol.type.isConjunct ? x.symbol.part(1) : x.name
    name := toChoiceSubTypeName(base, tag.capitalize)
    writeDoc(out, x)
    out.printLine("$name: $base { $tag }")
    out.printLine

    subtypes(x).each |sub| { writeChoiceItem(out, name, sub) }
  }

  private Str toChoiceSubTypeName(Str base, Str name)
  {
    switch (base)
    {
      case "AhuZoneDelivery": name = name[0..-5]
      case "AirVolumeAdjustability": name = name[0..-10]
      case "AtesDesign":     name = name[4..-1]
      case "CondenserLoop":  name = name[9..-5]
      case "CoolingProcess": name = name[0..-8]
      case "DuctConfig":     name = name[0..-5]
      case "DuctDeck":       name = name[0..-5]
      case "HeatingProcess": name = name[0..-8]
      case "MeterScope":     if (name == "SiteMeter") return "SiteMeterScope"
      case "PfScope":        name = name[2..-1]
      case "PfStandard":     name = name[2..-1]
      case "PhaseCount":     name = name[0..-6]
      case "PlantLoop":      name = name[0..-5]
      case "SimScenario":    name = name[3..-1]
    }

    return name + base
  }

  private Void writeChoiceTaxonomy(Def def)
  {
    write(`${def.name}.xeto`) |out|
    {
      writeChoiceTaxonomyLevel(out, def, "Choice")
    }
  }

  private Void writeChoiceTaxonomyLevel(OutStream out, Def def, Str baseName)
  {
    specName := toChoiceTypeName(def)
    tags := toChoiceTaxonomyTags(def)

    writeDoc(out, def)
    out.print("$specName: $baseName")
    if (tags != null) out.print(" { $tags }")
    out.printLine
    out.printLine

    subtypes := ns.subtypes(def)
    subtypes.sort |a, b| { a.name <=> b.name }
    subtypes.each |sub|
    {
      writeChoiceTaxonomyLevel(out, sub, specName)
    }
  }

  private Str? toChoiceTaxonomyTags(Def def)
  {
    sym := def.symbol
    if (sym.type.isTag)
    {
      name := sym.name
      if (isAbstract(name)) return null
      return name
    }

    part1 := def.symbol.part(0)
    part2 := def.symbol.part(1)

    supertype := ns.supertypes(def).first

    // co2-emission returns "co2"
    if (ns.fits(supertype, ns.def(part1))) return part2

    // hot-water returns "hot"
    if (ns.fits(supertype, ns.def(part2))) return part1

    // air-velocity returns "air, velocity"
    return "$part1, $part2"
  }

  private Str? choiceSimplify(Def def)
  {
    // these choices now just use their of
    of := def["of"]
    if (of != null) return of.toStr.capitalize
    return null
  }


  Def[] subtypes(Def def)
  {
    subtypes := ns.subtypes(def)
    subtypes.sort |a, b| { a.name <=> b.name }
    return subtypes
  }

//////////////////////////////////////////////////////////////////////////
// Write Feature Defs
//////////////////////////////////////////////////////////////////////////

  private Void writeFeatureDefs()
  {
    write(`filetypes.xeto`) |out|
    {
      out.printLine(
      Str<|// File format type definition
           Filetype: Feature {
             filetype         // Filetype marker
             fileExt:   Str?  // Filename extension such as "csv"
             mime:      Str?  // Mime type formatted as "type/subtype"
             wikipedia: Uri?  // Wikipedia link
           }
           |>)
      ns.filetypes.each |x| { writeFeatureInstance(out, x) }
    }

    write(`ops.xeto`) |out|
    {
      out.printLine(
      Str<|// Operation for HTTP API.  See `docHaystack::Ops` chapter.
           Op: Feature {
             // Op marker
             op

             // Marks a function or operation as having no side effects.  The function
             // may or may not be *pure* in that calling it multiple times with the
             // same arguments always evaluates to the same result.
             noSideEffects: Marker?
           }
           |>)
      ns.feature("op").defs.sort.each |x| { writeFeatureInstance(out, x) }
    }
  }

  private Void writeFeatureType(OutStream out, Def def)
  {
    type := def.name.capitalize
    tags := ns.tags(def)

    writeDoc(out, def)
    out.printLine("$type: Feature {")
    writeEntitySlots(out, def)
    out.printLine("}")
    out.printLine
  }

  private Void writeFeatureInstance(OutStream out, Def def)
  {
    type := def.symbol.part(0).capitalize

    writeDoc(out, def)
    out.printLine("@${def.symbol} : $type {")
    names := Etc.dictNames(def)
    names.removeAll(["def", "lib", "is", "doc"])
    names.sort
    names.each |n|
    {
      v := def[n]
      if (v === Marker.val)
        out.printLine("  $n")
      else
        out.printLine("  $n: $v.toStr.toCode")
    }
    out.printLine("}")
    out.printLine
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Namespace? ns    // compileNamespace
  private Lib? ph          // compileNamespace
}

