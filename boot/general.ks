// Boot script to Just open a terminal
@lazyglobal off.

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
set Terminal:HEIGHT to 46.
set Terminal:WIDTH to 60.
set Terminal:CHARHEIGHT to 11.
set Terminal:CHARWIDTH to 11.
set Terminal:BRIGHTNESS to 1.0.
