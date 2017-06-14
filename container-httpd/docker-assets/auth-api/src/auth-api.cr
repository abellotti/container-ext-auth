require "./auth-api/*"
require "kemal"
require "json"

def fetch_attr(output, attr)
  match = output.match(/^.*dict entry\([\s]+string \"#{attr}\"[\s]+variant[\s]+array \[[\s]+string \"([^\"]+)\".*\).*$/)
  match ? match[1] : nil
end

def parse_user_attrs(dbus_send_output)
  output = dbus_send_output.gsub(/\n/, ' ')
  {
    "mail"        => fetch_attr(output, "mail"),
    "givenname"   => fetch_attr(output, "givenname"),
    "sn"          => fetch_attr(output, "sn"),
    "displayname" => fetch_attr(output, "displayname")
  }
end

def parse_groups(dbus_send_output)
  output = dbus_send_output.gsub(/\n/, ' ')
  match = output.match(/^.*array \[[\s]+(.*)[\s]+\].*$/)
  return [] of String unless match
  match[1].gsub(/string[\s]+/, ' ').split.map do |group|
    name_match = group.match(/^\"(.*)\"$/)
    name_match.nil? ? nil : name_match[1]
  end
end

get "/api/dbus/user_attrs/:user" do |env|
  env.response.content_type = "application/json"
  user = env.params.url["user"]
  if user == ""
    gen_error(env, 400, "Must specified a :user with /api/dbus/user_attrs/:user")
  else
    cmd = "/usr/bin/dbus-send --print-reply --system --dest=org.freedesktop.sssd.infopipe /org/freedesktop/sssd/infopipe org.freedesktop.sssd.infopipe.GetUserAttr string:#{user} array:string:mail,givenname,sn,displayname"
    res = `#{cmd} 2>&1`
    $?.exit_status != 0 ? gen_error(env, 400, res) : { "result" => parse_user_attrs(res) }.to_json
  end
end

get "/api/dbus/groups/:user" do |env|
  env.response.content_type = "application/json"
  user = env.params.url["user"]
  if user == ""
    gen_error(env, 400, "Must specified a :user with /api/dbus/groups/:user")
  else
    cmd = "/usr/bin/dbus-send --print-reply --system --dest=org.freedesktop.sssd.infopipe /org/freedesktop/sssd/infopipe org.freedesktop.sssd.infopipe.GetUserGroups string:#{user}"
    res = `#{cmd} 2>&1`
    $?.exit_status != 0 ? gen_error(env, 400, res) : { "result" => parse_groups(res) }.to_json
  end
end

def gen_error(context, status, message)
  context.response.content_type = "application/json"
  context.response.status_code = status
  { "error" => message }.to_json
end

Kemal.run
