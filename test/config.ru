run lambda { |env|
  sleep env['REQUEST_URI'][/\d+/].to_i
  [200, {}, 'OK']
}
