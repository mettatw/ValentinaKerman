// Boot script to automatically do mission
@lazyglobal off.

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
set Terminal:HEIGHT to 46.
set Terminal:WIDTH to 60.
set Terminal:CHARHEIGHT to 11.
set Terminal:CHARWIDTH to 11.
set Terminal:BRIGHTNESS to 1.0.

switch to 1.
if not exists("1:/sync") {
  print "Start compiling things...".
  wait 5.

  compile "0:/sync.ks" to "1:/sync.ksm".
  run sync.
}

wait 5.
run go.
