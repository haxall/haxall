//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//

using util
using xeto

**
** Load and assign a SpecFactory to each AType in the AST
**
@Js
internal class LoadFactories : Step
{
  override Void run()
  {
    // check if we need to install a new factor loader
    typeName := pragma.meta.slot("factoryLoader")?.val?.str
    if (typeName != null) env.factories.install(typeName)

    // find a loader for our library
    loader := env.factories.loaders.find |x| { x.canLoad(lib.qname) }

    // if we have a loader, give it my type names to map to factories
    [Str:SpecFactory]? factories := null
    if (loader != null)
    {
      specNames := Str[,]
      lib.slots.each |spec|
      {
        if (spec.isType) specNames.add(spec.name)
      }
      factories = loader.load(lib.qname, specNames)
    }

    // now assign factories to all type level types
    lib.slots.each |spec|
    {
      if (spec.isType) assignFactory(spec, factories)
    }
  }

  private Void assignFactory(AType type, [Str:SpecFactory]? factories)
  {
    // lookup custom registered factory
    if (factories != null)
    {
      type.factoryRef = factories[type.name]
    }

    // if (type.factoryRef != null) echo("INSTALL $type.qname => $type.factory")

    // install default dict/scalar factory
    if (type.factoryRef == null)
    {
      if (type.flags.and(MSpecFlags.scalar) != 0)
        type.factoryRef = env.factories.scalar
      else
        type.factoryRef = env.factories.dict
    }
  }

}