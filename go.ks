// Call a function
@lazyglobal off.

if core:part:tag:length > 0 {
  runpath("mission/" + core:part:tag).
} else {
  print "Go: no part tag specified, exiting".
}
