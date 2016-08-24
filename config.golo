module config

function config = {
  return DynamicObject()
    : token(System.getenv("TOKEN_GITHUB_ENTERPRISE"))
    : http_port(8888)
    : enterprise(true)
    : host("ghe.k33g")
    : scheme("http")
    : port(-1)
}

# GitHub.com host("api.github.com")
