## ci.golo ... ... 
function do = |context| {
  println("=== Jarvis-CI === [wip-again]")
  let path = currentDir() + "/" + context: tmp_dir()
  println(path)
  # Stage: initialize
  println("1- initialize")
  if context: sh("./npm_install.sh {0}", path): equals(0) {
    println("packages installation OK")
    # Stage: tests
    println("2- tests")
    if context: sh("./npm_run.sh {0} {1}", path, "test"):  equals(0) {
      println("tests OK")
      return DynamicObject(): initialize("ok"): tests("ok"): status("success"): description("you are the best!"): context("jarvis-ci")
    } else {
      println("tests KO")
      return DynamicObject(): initialize("ok"): tests("ko"): status("failure"): description("ouch!"): context("jarvis-ci")
    }
  } else {
    println("packages installation KO")
    return DynamicObject(): initialize("ko"): tests("ko"): status("failure"): description("ouch!"): context("jarvis-ci")
  }

}
