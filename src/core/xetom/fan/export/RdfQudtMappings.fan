//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Aug 2026  Creation
//

using xeto

**
** Strict access to the canonical Xeto-to-QUDT resources packaged by sys.rdf.
**
@NoDoc @Js
const class RdfQudtMappings
{
  ** Load and validate the canonical resources from the active namespace.
  static RdfQudtMappings load(Namespace ns)
  {
    lib := ns.lib("sys.rdf", false)
      ?: throw IOErr("RDF QUDT mappings require the sys.rdf library")
    unitsFile := lib.files.get(`/qudt-units.props`, false)
      ?: throw IOErr("sys.rdf is missing /qudt-units.props")
    quantitiesFile := lib.files.get(`/qudt-quantities.props`, false)
      ?: throw IOErr("sys.rdf is missing /qudt-quantities.props")
    return make(unitsFile.readAllStr, quantitiesFile.readAllStr)
  }

  ** Parse source strings. Public for focused validation tests.
  new make(Str unitsSource, Str quantitiesSource)
  {
    unitRows := parseProps("qudt-units.props", unitsSource)
    if (unitRows.isEmpty) throw IOErr("qudt-units.props: mapping resource is empty")
    unitRows.each |Str target, Str name|
    {
      unit := Unit.fromStr(name, false)
      if (unit == null || unit.name != name)
        throw IOErr("qudt-units.props: unknown canonical Xeto unit '$name'")
      validateTarget("qudt-units.props", name, target)
    }

    quantityRows := parseProps("qudt-quantities.props", quantitiesSource)
    if (quantityRows.isEmpty) throw IOErr("qudt-quantities.props: mapping resource is empty")
    quantities := Str:Str[][:]
    quantityRows.each |Str targets, Str name|
    {
      quantity := UnitQuantity.fromStr(name, false)
      if (quantity == null || quantity.name != name)
        throw IOErr("qudt-quantities.props: unknown Xeto quantity '$name'")
      Str[] parsed := targets.split(',').map |Str target->Str| { target.trim }
      if (parsed.isEmpty || parsed.any { it.isEmpty })
        throw IOErr("qudt-quantities.props: empty QUDT target for '$name'")
      seen := Str:Bool[:]
      parsed.each |target|
      {
        validateTarget("qudt-quantities.props", name, target)
        if (seen[target] == true)
          throw IOErr("qudt-quantities.props: duplicate QUDT target '$target' for '$name'")
        seen[target] = true
      }
      quantities[name] = parsed.toImmutable
    }

    this.units = unitRows.toImmutable
    this.quantities = quantities.toImmutable
  }

  ** Map a runtime unit, resolved from any accepted name or symbol, to QUDT.
  Str unit(Unit unit)
  {
    target := units[unit.name]
      ?: throw UnsupportedErr("No reviewed QUDT mapping for Xeto unit '${unit.name}'")
    quantity := UnitQuantity.unitToQuantity[unit]
      ?: throw UnsupportedErr("Xeto unit '${unit.name}' has no runtime quantity")
    prefix := quantity == UnitQuantity.currency ? "currency" : "unit"
    return "${prefix}:${target}"
  }

  ** Map one Xeto quantity to all accepted QUDT quantity-kind alternatives.
  Str[] quantity(UnitQuantity quantity)
  {
    quantities[quantity.name]
      ?: throw UnsupportedErr("No reviewed QUDT mapping for Xeto quantity '${quantity.name}'")
  }

  ** Number of mapped canonical units.
  Int unitCount() { units.size }

  ** Number of mapped Xeto quantities.
  Int quantityCount() { quantities.size }

  private static Str:Str parseProps(Str file, Str source)
  {
    rows := Str:Str[:]
    lines := Str:Int[:]
    source.splitLines.each |sourceLine, index|
    {
      lineNum := index + 1
      row := sourceLine.trim
      if (row.isEmpty || row.startsWith("//") || row.startsWith("#")) return

      equals := row.index("=")
      if (equals == null || equals == 0 || equals == row.size-1 ||
          row.index("=", equals + 1) != null)
        throw IOErr("${file}:${lineNum}: expected one non-empty name=value row")

      name := row[0..<equals].trim
      value := row[equals+1..-1].trim
      if (name.isEmpty || value.isEmpty)
        throw IOErr("${file}:${lineNum}: expected one non-empty name=value row")
      firstLine := lines[name]
      if (firstLine != null)
        throw IOErr("${file}:${lineNum}: duplicate mapping '$name'; first declared on line $firstLine")
      rows[name] = value
      lines[name] = lineNum
    }
    return rows
  }

  private static Void validateTarget(Str file, Str name, Str target)
  {
    if (!qudtLocalName.matches(target))
      throw IOErr("${file}: invalid QUDT target '$target' for '$name'")
  }

  private static const Regex qudtLocalName := Regex<|[A-Za-z_][A-Za-z0-9._-]*|>

  private const Str:Str units
  private const Str:Str[] quantities
}
