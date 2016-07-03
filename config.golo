module config

function config = {
  return DynamicObject()
    : token("your_token_here")
    : http_port(8888)
    : host("api.github.com")
}