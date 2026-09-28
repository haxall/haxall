//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Sep 2026  Rex Fenley  Creation
//

using concurrent
using dom
using xeto

**
** Maps Xeto units and quantities to the QUDT vocabulary.
**
@NoDoc @Js
const class RdfQudtMap
{
  ** Load the mappings packaged by sys.rdf.  The server resolves the lib
  ** directly; the browser cannot, so it must fetch the two props files
  ** over HTTP and install them first.
  static RdfQudtMap load()
  {
    cur := curRef.val as RdfQudtMap
    if (cur != null) return cur
    if (Env.cur.isBrowser) throw UnsupportedErr("RdfQudtMap not installed in browser")
    lib := XetoEnv.cur.resolveNamespace(["sys.rdf"]).lib("sys.rdf")
    units := (Str:Str)lib.files.get(`/qudt-units.props`).read |in| { in.readProps }
    quantities := (Str:Str)lib.files.get(`/qudt-quantities.props`).read |in| { in.readProps }
    unmapped := (Str:Str)lib.files.get(`/qudt-unmapped-quantities.props`).read |in| { in.readProps }
    return install(units, quantities, unmapped)
  }

  ** Is the map loaded and cached
  static Bool isLoaded() { curRef.val != null }

  ** Install the map from the parsed contents of the sys.rdf props files
  static RdfQudtMap install(Str:Str units, Str:Str quantities, Str:Str unmapped)
  {
    curRef.val = make(units, quantities, unmapped)
  }

  ** Load the map in the browser by fetching the props files from the
  ** given base URI for the sys.rdf lib files, such as the file space
  ** lib mount `/api/demo/file/lib/sys.rdf/`.  Return future that
  ** completes once the map is installed.
  static Future loadBrowser(Uri baseUri)
  {
    future := Future.makeCompletable
    if (isLoaded) return future.complete(load)
    fetchProps(baseUri + `qudt-units.props`, future) |units|
    {
      fetchProps(baseUri + `qudt-quantities.props`, future) |quantities|
      {
        fetchProps(baseUri + `qudt-unmapped-quantities.props`, future) |unmapped|
        {
          future.complete(install(units, quantities, unmapped))
        }
      }
    }
    return future
  }

  ** Fetch and parse one props file, completing the future on error
  private static Void fetchProps(Uri uri, Future future, |Str:Str| onOk)
  {
    HttpReq { it.uri = uri }.get |res|
    {
      if (res.status != 200) { future.completeErr(IOErr("Cannot load $uri [$res.status]")); return }
      try
        onOk(res.content.in.readProps)
      catch (Err e)
        future.completeErr(e)
    }
  }

  private static const AtomicRef curRef := AtomicRef()

  private new make(Str:Str units, Str:Str quantityProps, Str:Str unmapped)
  {
    quantities := Str:Str[][:]
    quantityProps.each |targets, name|
    {
      quantities[name] = targets.split(',').map |target->Str| { target.trim }.toImmutable
    }
    this.unmapped = unmapped.toImmutable
    this.units = units.toImmutable
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

  ** Map one Xeto quantity to its accepted QUDT quantity-kind alternatives.
  Str[] quantity(UnitQuantity quantity)
  {
    quantities[quantity.name]
      ?: throw UnsupportedErr("No reviewed QUDT mapping for Xeto quantity '${quantity.name}'")
  }

  ** Correspondence links do not determine a standalone quantity's identity.
  Str[] quantityLinks(UnitQuantity quantity)
  {
    targets := quantities[quantity.name]
    if (targets != null) return targets
    if (unmapped.containsKey(quantity.name)) return Str[,]
    throw UnsupportedErr("No reviewed QUDT classification for Xeto quantity '${quantity.name}'")
  }

  private const Str:Str unmapped
  private const Str:Str units
  private const Str:Str[] quantities
}
