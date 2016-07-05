module jarvisci

import java.text.MessageFormat

import gololang.Errors
import spark.Spark

import org.eclipse.egit.github.core.client.GitHubClient
import org.eclipse.egit.github.core.client.GitHubRequest

import config


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

function getGitHubClient = {
  var gitHubClient = null
  if config(): enterprise() {
    gitHubClient = GitHubClient(config(): host(), config(): port(), config(): scheme())
  } else {
    gitHubClient = GitHubClient(config(): host())
  }
  gitHubClient: setOAuth2Token(config(): token())
  return gitHubClient
}

function console = -> 
  DynamicObject()
    : log(|this, txt, args...| -> println(MessageFormat.format(txt, args)))


function getExecuteorHelper = ->
  DynamicObject()
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

----
TODO: 
- use EvaluationEnvironment to load config
- try to see how I can test my golo project
----
function main = |args| {

  let executorHelper = getExecuteorHelper()

  let env = gololang.EvaluationEnvironment()

  setPort(config(): http_port())

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

    #console(): log("GitHub Event: {0}", eventName)

    let data = JSON.parse(request: body())

    let action = data: get("action")
    let after = data: get("after")
    let owner = data: get("repository"): get("owner"): get("name")
    let repoName = data: get("repository"): get("name")
    let statuses_url = "/repos/" + owner + "/" + repoName + "/statuses/" + after

    let gitHubClient = getGitHubClient()

    if eventName: equals("pull_request") { }

    if eventName: equals("push") {

      let repo = getRepository(data)
      executorHelper: tmp_dir("clones/" + uuid() + "-" +repo: name() + "-" + repo: branchName())
      
      if executorHelper: clone(repo): equals(0) {

        if executorHelper: checkout(repo: branchName()):equals(0) {

          let displayError = |sourceError| -> 
                                |error| -> 
                                  console(): log(
                                    "💔  Error from {0}: {1}", 
                                    sourceError orIfNull "🌏", 
                                    error orIfNull "😵"
                                  )
          
          let doNothing = |value| -> console(): log("{0}", value orIfNull "I'm fine 😃")

          # Building closure.
          let runCiGolo = |goloSourceCode| {

            # Initialize and build
            trying({

              # TODO: run as a worker or a thread and kill it if to long

              # Run `check` function in `ci.golo`
              let results = fun(
                "check", 
                env: anonymousModule(goloSourceCode)
              )(executorHelper)
              
              # TODO check result properties
              # TODO display messages with emoji

              # Check and display results
              console(): log("results: {0}", JSON.stringify(results))

              console(): log("statuses_url: {0}", statuses_url)
              
              # Change status depending of build result
              trying({
                gitHubClient: post(statuses_url, 
                  map[
                    ["state", results?: status() orIfNull "pending"],
                    ["description", results?: description() orIfNull "Warning: status are not defined"],
                    ["context", results?: context() orIfNull "jarvis-ci"]
                  ], 
                  java.lang.Object.class
                )

                return "🐼  GitHub status are passed"
              }): either(doNothing  ,displayError("[status]")) 


              return "🐯  check() from ci.golo was executed"
            }): either(doNothing  ,displayError("[check()]"))


          } # end of runCiGolo


          # change status at the begining of checking
          trying({
            gitHubClient: post(statuses_url, 
              map[
                ["state", "pending"],
                ["description", "Jarvis-CI is checking..."],
                ["context", "jarvis-ci"]
              ], 
              java.lang.Object.class
            )
            return "🍄  GitHub pending status are passed"
          }): either(doNothing  ,displayError("[status:pending]"))
          
          # Try loading ci.golo from the current branch
          # and run ci if ok
          trying({
            return fileToText(executorHelper: tmp_dir()+"/ci.golo", "UTF-8")
          })
          : either(runCiGolo ,displayError)

        } # end of checkout
      } # end of clone

    } # end of push
    return JSON.stringify(DynamicObject(): message("Hello from Golo-CI"))
  })
 
}


