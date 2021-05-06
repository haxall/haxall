//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Sep 2018  Brian Frank  Creation
//

package fan.hxStore;

import fan.sys.ArgErr;
import fan.sys.Duration;
import fan.sys.Map;

/**
 * Opts map utilities
 */
final class Opts
{

  static String getStr(Map opts, String key, String def)
  {
    if (opts == null) return def;
    Object val = opts.get(key);
    if (val == null) return def;
    return val.toString();
  }

  static Duration getDur(Map opts, String key, Duration def)
  {
    if (opts == null) return def;
    Object val = opts.get(key);
    if (val == null) return def;
    if (!(val instanceof Duration)) throw ArgErr.make("Opt not Duration: " + key + " = " + val);
    return (Duration)val;
  }

  static int getInt(Map opts, String key, int def)
  {
    if (opts == null) return def;
    Object val = opts.get(key);
    if (val == null) return def;
    if (!(val instanceof Long)) throw ArgErr.make("Opt not Int: " + key + " = " + val);
    long j = ((Long)val).longValue();
    if (j > Integer.MAX_VALUE) throw ArgErr.make("Opt out of range: " + key + " = " + val);
    return (int)j;
  }

}