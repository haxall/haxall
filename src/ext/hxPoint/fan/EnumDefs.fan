//
// Copyright (c) 2014, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Nov 2014  Brian Frank  Creation
//

using xeto
using concurrent
using haystack

**
** EnumDefs handles the 'enumMeta' rec to define enumerated name/code mappings
**
@NoDoc
const class EnumDefs
{
  ** List currently defined enums
  EnumDef[] list()
  {
    ((Str:EnumDef)byName.val).vals.sort |a, b| { a.id <=> b.id }
  }

  ** Lookup an enum by name
  EnumDef? get(Str id, Bool checked := true)
  {
    enum := ((Str:EnumDef)byName.val).get(id)
    if (enum != null) return enum
    if (checked) throw UnknownNameErr("enum def: $id")
    return null
  }

  ** Cached value of 'enumMeta' record
  Dict meta() { metaRef.val }

  ** Callback from house keeping
  @NoDoc Void updateMeta(Dict cur, Log log)
  {
    // short circuit if same rec instance
    old := meta
    if (cur === old || old["mod"] == cur["mod"]) return

    // rebuild the EnumDef mappings
    try
    {
      acc := Str:EnumDef[:]
      cur.each |val, name|
      {
        grid := toGrid(val)
        if (grid == null) return
        try
          acc[name] = EnumDef(name, grid)
        catch (Err e)
          log.err("Invalid enum def: $name", e)
      }

      byName.val = acc.toImmutable
      metaRef.val = cur
    }
    catch (Err e) log.err("updateMeta", e)
  }

  private Grid? toGrid(Obj? val)
  {
    if (val is Grid) return val
    if (val is Str && val.toStr.startsWith("ver:")) return ZincReader(val.toStr.in).readGrid
    return null
  }

  private const AtomicRef metaRef := AtomicRef(Etc.dict0)
  private const AtomicRef byName := AtomicRef(Str:EnumDef[:].toImmutable)

}

**************************************************************************
** EnumDef
**************************************************************************

@NoDoc
const class EnumDef
{
  internal new make(Str id, Grid grid)
  {
    trueName := null
    falseName := null
    nameToCodeMap := Str:Number[:]
    codeToNameMap := Number:Str[:]
    grid.each |row, i|
    {
      name := (Str)row->name
      code := row["code"] as Number ?: Number(i)
      if (trueName == null && code.toInt != 0) trueName = name
      if (falseName == null && code.toInt == 0) falseName = name
      if (nameToCodeMap[name] == null) nameToCodeMap.add(name, code)
      if (codeToNameMap[code] == null) codeToNameMap.add(code, name)
    }
    this.id = id
    this.grid = grid
    this.nameToCodeMap = nameToCodeMap
    this.codeToNameMap = codeToNameMap
    this.trueName = trueName
    this.falseName = falseName
  }

  internal new makeEnumTag(Str enums)
  {
    trueName := null
    falseName := null
    nameToCodeMap := Str:Number[:]
    codeToNameMap := Number:Str[:]
    enums.split(',').each |name, index|
    {
      code := Number(index)
      if (trueName == null && code.toInt != 0) trueName = name
      if (falseName == null && code.toInt == 0) falseName = name
      if (nameToCodeMap[name] == null) nameToCodeMap.add(name, code)
      if (codeToNameMap[code] == null) codeToNameMap.add(code, name)
    }
    this.id = "self"
    this.nameToCodeMap = nameToCodeMap
    this.codeToNameMap = codeToNameMap
    this.trueName = trueName
    this.falseName = falseName
  }

  public Int size() { grid.size }

  public Number? nameToCode(Str name, Bool checked := true)
  {
    code := nameToCodeMap[name]
    if (code != null) return code
    if (checked) throw UnknownNameErr("nameToCode: $name")
    return null
  }

  public Str? codeToName(Number code, Bool checked := true)
  {
    name := codeToNameMap[code]
    if (name != null) return name
    if (checked) throw UnknownNameErr("codeToName: $code")
    return null
  }

  public const Str id
  public const Grid? grid
  public const Str? trueName
  public const Str? falseName
  private const Str:Number nameToCodeMap
  private const Number:Str codeToNameMap
}

