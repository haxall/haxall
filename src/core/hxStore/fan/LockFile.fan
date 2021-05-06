//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jun 2016  Brian Frank  Creation
//

using concurrent
using [java] fanx.interop
using [java] java.io::RandomAccessFile

**
** LockFile is used to acquire an exclusive lock to prevent
** two different processes from using same files
**
const class LockFile
{
  new make(File file) { this.file = file }

  const File file

  private const AtomicRef fpRef := AtomicRef()

  ** Acquire the lock or raise CannotAcquireLockFileErr
  Void acquire()
  {
    // use java.nio.LockFile
    file.parent.create
    jfile := Interop.toJava(file)
    fp := RandomAccessFile(jfile, "rw")
    lock := fp.getChannel.tryLock
    if (lock == null) throw CannotAcquireLockFileErr(file.osPath)

    // save away the fp
    fpRef.val = Unsafe(fp)

    // write info about who is creating this lock file
    fp.writeBytes(
       """locked=${DateTime.now}
          homeDir=${Env.cur.homeDir.osPath}
          version=${typeof.pod.version}""")
    fp.getFD.sync
  }

  ** Release the lock if we are holding one
  Void release()
  {
    fp := (fpRef.val as Unsafe)?.val as RandomAccessFile
    if (fp != null) fp.close
    file.delete
  }

  ** Command line test program
  static Void main(Str[] args)
  {
    file := `test.lock`.toFile.normalize
    echo
    echo("Acquiring: $file.osPath ...")
    LockFile(file).acquire
    echo("Acquired!")
    echo
    echo("Run this program in another console and verify CannotAcquireLockFileErr")
    echo("Waiting, use Ctrl+C to end ...")
    Actor.sleep(1day)
  }
}

** When another process has var directory locked
@NoDoc
const class CannotAcquireLockFileErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}