// Boot script to automatically do mission
@lazyglobal off.

wait 3.

if ship = kuniverse:activevessel {
  if not core:part:tag:startswith("INACTIVE") {
    CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
    set Terminal:CHARHEIGHT to 11.
    set Terminal:CHARWIDTH to 11.
    set Terminal:HEIGHT to 40.
    set Terminal:WIDTH to 45.
    set Terminal:BRIGHTNESS to 1.0.
  }
}

switch to 1.
if not exists("1:/sync") {
  print "Start compiling things...".
  wait 5.

  compile "0:/sync.ks" to "1:/sync.ksm".
  run sync.
}
if not exists("1:/boot/auto") {
  copypath("0:/boot/auto", "1:/boot/auto").
}

wait 3.
if not core:part:tag:startswith("INACTIVE") {
  run go.
} else {
  shutdown.
}
