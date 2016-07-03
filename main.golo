module jarvisci


import java.text.MessageFormat

# https://mvnrepository.com/artifact/org.kohsuke/github-api/1.76
# http://central.maven.org/maven2/org/kohsuke/github-api/1.76/

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
    println("GitHub Event: " + eventName)
    let data = JSON.parse(request: body())

    #textToFile(JSON.stringify(data), "foo3.json")

    let action = data: get("action")
    let after = data: get("after")
    let owner = data: get("repository"): get("owner"): get("name")
    let repoName = data: get("repository"): get("name")
    let statuses_url = "/repos/" + owner + "/" + repoName + "/statuses/" + after


    let gitHubClient = GitHubClient(config(): host())
    gitHubClient: setOAuth2Token(config(): token())

    if eventName: equals("pull_request") {

    }

    if eventName: equals("push") {


      let repo = getRepository(data)
      RT: tmp_dir("clones/" + uuid() + "-" + repo: branchName())
      
      if RT: clone(repo): equals(0) {

        if RT: checkout(repo: branchName()):equals(0) {


          try {
            gitHubClient: post(statuses_url, 
              map[
                ["state", "pending"],
                ["description", "Jarvis-CI is checking..."],
                ["context", "jarvis-ci"]
              ], 
              java.lang.Object.class
            )
          } catch (e) {
            e: printStackTrace()
          }   

          let runCiGolo = |content| {
            let results = fun("do", env: anonymousModule(content))(RT)

            println(JSON.stringify(results))

            #textToFile(JSON.stringify(data), "foo2.json")

            # here, something to do with status
            # to do: test validity of results

            println(statuses_url)

            try {
              gitHubClient: post(statuses_url, 
                map[
                  ["state", results?: status() orIfNull "pending"],
                  ["description", results?: description() orIfNull "status are not defined"],
                  ["context", results?: context() orIfNull "jarvis-ci"]
                ], 
                java.lang.Object.class
              )
            } catch (e) {
              e: printStackTrace()
            }   


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


