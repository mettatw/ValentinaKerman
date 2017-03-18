// The REAL sync function
@lazyglobal off.

function buildOneFile {
  parameter parName.
  local src is "0:/" + parName.
  local dest is "1:/" + parName + "m".
  compile src to dest.
  print "Compiled: " + dest.
}

function doSync {
  local listDirs is list("sub", "lib").
  local listFiles is list("call.ks", "go.ks", "killnode.ks", "launch.ks", "node.ks").

  local f is 0.
  for f in listFiles {
    buildOneFile(f).
  }

  local d is 0.
  for d in listDirs {
    if not exists("1:/" + d) {
      volume(1):createdir("/" + d).
    }
    local thisDir is volume(0):open("/" + d).
    for f in thisDir:list:keys {
      buildOneFile(d + "/" + f).
    }
  }

  // Mission script
  local tagReal is core:part:tag.
  if tagReal:startswith("INACTIVE") {
    set tagReal to tagReal:replace("INACTIVE:", "").
  }
  if tagReal:length > 0 {
    buildOneFile("mission/" + tagReal + ".ks").
  }
}
print "".
doSync().
print "".
