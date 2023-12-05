//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Aug 2022  Brian Frank  Creation
//   22 Mar 2023  Brian Frank  Refactor from original design
//

using util
using haystack
using defc

internal class GenPH : XetoCmd
{
  override Str name() { "gen-ph" }

  override Str summary() { "Compile haystack defs into xeto ph lib" }

  @Opt { help = "Directory to output" }
  File outDir := Env.cur.workDir + `src/xeto/ph/`

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
    // get all the entity defs
    tags := Def[,]
    ns.eachDef |def| { if (def.symbol.type.isTag) tags.add(def) }
    tags.sort |a, b| { a.name <=> b.name }

    write(`tags.xeto`) |out|
    {
      tags.each |def|
      {
        name := def.name
        kind := ns.defToKind(def)
        meta := toTagMeta(def, kind)

        if (excludeTag(def, kind)) return

        writeDoc(out, def)
        out.printLine("$name: $kind.name $meta".trim)
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
    if (n == "enum") return true
    if (n == "is") return true
    if (n == "mandatory") return true
    if (n == "notInherited") return true
    if (n == "tagOn") return true
    if (n == "transient") return true

    return false
  }

  private const Symbol defSymbol := Symbol("def")

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
        return "<of:$ofName>"
      }
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
    entities.sort |a, b| { a.name <=> b.name }
    entities.moveTo(entityDef, 0)

    write(`entities.xeto`) |out|
    {
      entities.each |def|
      {
        writeDoc(out, def)
        name := toEntityName(def)
        type := toEntityType(def)
        out.print("$name: $type")
        writeEntityMeta(out, def)
        out.printLine(" {")
        writeEntityUsage(out, def)
        //writeEntityTags(out, def)
        writeEntityChildren(out, def)
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
    supers := def["is"] as Symbol[]
    return toEntityName(ns.def(supers.first.toStr))
  }

  private Void writeEntityMeta(OutStream out, Def entity)
  {
    symbol := entity.symbol
    name := symbol.name

    // make space/equip/point abstract
    special := name == "space" || name == "equip" || name == "point" || name.endsWith("-point")

    if (!isAbstract(name) && !special) return

    out.print(" <abstract>")
  }

  private Void writeEntityUsage(OutStream out, Def entity)
  {
    symbol := entity.symbol
    name := symbol.name

    if (isAbstract(name)) return

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

  private Bool isAbstract(Str name)
  {
    // not sure how to best handle this, but for now just
    // consider these tags as abstract
    name == "airHandlingEquip" ||
    name == "airQualityZonePoints" ||
    name == "airTerminalUnit" ||
    name == "conduit" ||
    name == "coil" ||
    name == "entity" ||
    name == "radiantEquip" ||
    name == "verticalTransport"
  }

/*
  private Void writeEntityTags(OutStream out, Def entity)
  {
    tags := Def[,]
    maxNameSize := 2
    ns.tags(entity).each |tag|
    {
      if (isInherited(entity, tag)) return
      if (skip(tag.name)) return
      tags.add(tag)
      maxNameSize = maxNameSize.max(tag.name.size)
    }

    tags.sort |a, b| { a.name <=> b.name }

    tags.each |tag|
    {
      out.printLine("  $tag: " + Str.spaces(maxNameSize-tag.toStr.size) + "ph.Tag.$tag?")
    }
  }
*/

  private Void writeEntityChildren(OutStream out, Def entity)
  {
    // insert queries
    if (entity.name == "equip")  out.printLine("  points: Query<of:Point, inverse:\"ph::Point.equips\">  // Points contained by this equip")
    if (entity.name == "point")  out.printLine("  equips: Query<of:Equip, via:\"equipRef+\">  // Parent equips that contain this point")
  }

  private Bool isInherited(Def entity, Def tag)
  {
    on := tag["tagOn"] as Symbol[]
    return !on.contains(entity.symbol)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Write given file under phDir
  Void write(Uri file, |OutStream| cb)
  {
    info("write [$file]")
    f := outDir + file
    out := f.out
    try
    {
      out.printLine("// Auto-generated $ts")
      out.printLine
      cb(out)
    }
    finally out.close
  }


  ** Write doc comment
  Void writeDoc(OutStream out, Def def)
  {
    doc := def["doc"] as Str ?: def.name
    doc.splitLines.each |line|
    {
      out.printLine("// $line".trimEnd)
    }
  }

  ** Log message to stdout
  Void info(Str msg)
  {
    echo(msg)
  }

  ** Skip tag
  private Bool skip(Str name)
  {
    // TODO: chillerMechanism and vavAirCircuit have conjuncts
    name ==  "chillerMechanism" || name ==  "vavAirCircuit"
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const Str ts := DateTime.now.toLocale("DD-MMM-YYYY")

  private Namespace? ns    // compileNamespace
  private Lib? ph          // compileNamespace
}


