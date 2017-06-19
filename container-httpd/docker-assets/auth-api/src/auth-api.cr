require "./auth-api/*"
require "kemal"
require "dbus"
require "json"

get "/api/dbus/user_attrs/:user" do |env|
  user = env.params.url["user"]
  env.response.content_type = "application/json"
  attrs_needed = %w(mail givenname sn display).as Array(String)

  bus = DBus::Bus.new(LibDBus::BusType::SYSTEM)
  obj = bus.object("org.freedesktop.sssd.infopipe", "/org/freedesktop/sssd/infopipe")
  interface = obj.interface("org.freedesktop.sssd.infopipe")
  user_attrs = interface.call("GetUserAttr", [ user, attrs_needed ]).reply[0]

  if user_attrs == "No such user"
    gen_error(env, 400, "No such user")
  else
    hash_result = Hash(String, String).new
    if user_attrs.is_a? Hash(DBus::Type, DBus::Type)
      user_attrs.each do |key, dbus_value|
        if dbus_value.is_a?(DBus::Variant)
          value = dbus_value.value
          if value.is_a?(Array(DBus::Type))
            hash_result[key.as String] = value.first.as String
          end
        end
      end
    end
    { "result" => hash_result }.to_json
  end
end

get "/api/dbus/groups/:user" do |env|
  user = env.params.url["user"]
  env.response.content_type = "application/json"

  bus = DBus::Bus.new(LibDBus::BusType::SYSTEM)
  obj = bus.object("org.freedesktop.sssd.infopipe", "/org/freedesktop/sssd/infopipe")
  interface = obj.interface("org.freedesktop.sssd.infopipe")
  groups = interface.call("GetUserGroups", [ user ]).reply[0]

  if groups.is_a?(Array(DBus::Type))
    { "result" => groups.map { |group| group.as String } }.to_json
  else
    gen_error(env, 500, "Unsupported Dbus type returned by GetUserGroups")
  end
end

def gen_error(context, status, message)
  context.response.content_type = "application/json"
  context.response.status_code = status
  { "error" => message }.to_json
end

Kemal.run
