// Call a function
@lazyglobal off.

if core:part:tag:length > 0 {
  runpath("0:/mission/" + core:part:tag).
} else {
  print "Go: no part tag specified, exiting".
}
