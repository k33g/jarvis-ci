module gh3


import org.kohsuke.github.GitUser
import org.kohsuke.github.GHRepository
import org.kohsuke.github.GitHub

import java.text.MessageFormat

# https://mvnrepository.com/artifact/org.kohsuke/github-api/1.76
# http://central.maven.org/maven2/org/kohsuke/github-api/1.76/

import gololang.Errors
import spark.Spark


function getGitHubEvent = |request| -> request: headers("X-GitHub-Event")

function getRepository = |data| -> 
  DynamicObject()
    : html_url(data: get("repository"): get("html_url"))
    : ssh_url(data: get("repository"): get("ssh_url"))
    : url(data: get("repository"): get("url"))
    : full_name(data: get("repository"): get("full_name"))
    : name(data: get("repository"): get("name"))
    : ref(data: get("ref"))
    : branchName(|this| -> this: ref(): split("/"): asList(): last())

function main = |args| {

  let RT = DynamicObject()
    : shell(|this, cmd| {
        let p = Runtime.getRuntime(): exec(cmd)
        return p: waitFor()
      })
    : sh(|this, cmd, args...| {
        let p = Runtime.getRuntime(): exec(MessageFormat.format(cmd, args))
        return p: waitFor()
      })    
    : tmp_dir(null)
    : checkout(|this, branchName| -> this: shell("./checkout.sh " + this: tmp_dir() + " " + branchName))
    : clone(|this, repo| -> this: shell("git clone " + repo: url() + ".git " + this: tmp_dir()))

  let env = gololang.EvaluationEnvironment()

  setPort(8888)

  spark.Spark.get("/", |request, response| {
    response: type("application/json")
    return JSON.stringify(DynamicObject(): message("Hello from Golo-CI"))
  })

  spark.Spark.get("/golo_ci", |request, response| {
    response: type("application/json")
    return JSON.stringify(DynamicObject(): message("Hello from Golo-CI"))
  })
  # Add a wehook to GhitHub Enterprise
  # http://zeiracorp.local:8888/golo_ci
  spark.Spark.post("/golo_ci", |request, response| {
    response: type("application/json")
    let eventName = getGitHubEvent(request)
    println("GitHub Event: " + eventName)
    let data = JSON.parse(request: body())

    if eventName: equals("push") {
      let repo = getRepository(data)
      RT: tmp_dir("clones/" + uuid() + "-" + repo: branchName())
      
      if RT: clone(repo): equals(0) {

        if RT: checkout(repo: branchName()):equals(0) {

          let runCiGolo = |content| {
            let results = fun("do", env: anonymousModule(content))(RT)
            println(JSON.stringify(results))
            # here, something to do with status
          }

          let displayError = |error| -> println(error)

          # Try loading ci.golo from the current branch
          trying({
            return fileToText(RT: tmp_dir()+"/ci.golo", "UTF-8")
          })
          : either(runCiGolo ,displayError)

        }
      }

    }
    return JSON.stringify(DynamicObject(): message("Hello from Golo-CI"))
  })
 
}


