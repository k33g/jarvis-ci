module config

function config = {
  return DynamicObject()
    : token("56fc42a6646aebe8af59e2bc980e8744bec5579d")
    : http_port(8888)
    : enterprise(true)
    : host("ghe.k33g")
    : scheme("http")
    : port(-1)
}

# GitHub.com host("api.github.com")