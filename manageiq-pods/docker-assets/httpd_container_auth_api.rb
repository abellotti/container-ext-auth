require 'json'
require 'faraday'

Rails.configuration.to_prepare do
  MiqGroup.class_eval do
    def self.get_httpd_groups_by_user(user)
      # if ENV["CONTAINER"]
      get_httpd_groups_by_user_via_auth_api(user)
      # else
      #   get_httpd_groups_by_user_via_dbus(user)
      # end
    end

    def self.get_httpd_groups_by_user_via_auth_api(user)
      conn = Faraday.new(:url => "http://httpd:4100") do |faraday|
        faraday.request(:url_encoded)               # form-encode POST params
        faraday.adapter(Faraday.default_adapter)    # make requests with Net::HTTP
      end

      begin
        response = conn.run_request(:get, "/GetUserGroups", nil, nil) do |req|
          req.headers[:content_type] = "application/json"
          req.headers[:accept]       = "application/json"
          req.params.merge!("user" => user)
        end
      rescue => err
        raise("Failed to connect to the httpd container Authentication API service - #{err}")
      end

      if response.body
        body = JSON.parse(response.body.strip)
      end

      raise(body["error"]) if response.status >= 400
      strip_group_domains(body["result"])
    end

    def self.get_httpd_groups_by_user_via_dbus(user)
      require "dbus"

      username = user.kind_of?(self) ? user.userid : user

      sysbus = DBus.system_bus
      ifp_service   = sysbus["org.freedesktop.sssd.infopipe"]
      ifp_object    = ifp_service.object "/org/freedesktop/sssd/infopipe"
      ifp_object.introspect
      ifp_interface = ifp_object["org.freedesktop.sssd.infopipe"]
      begin
        user_groups = ifp_interface.GetUserGroups(user)
      rescue => err
        raise _("Unable to get groups for user %{user_name} - %{error}") % {:user_name => username, :error => err}
      end
      strip_group_domains(user_groups.first)
    end
  end

  Authenticator::Httpd.class_eval do
    def user_attrs_from_external_directory(username)
      # if ENV["CONTAINER"]
      user_attrs_from_external_directory_via_auth_api(username)
      # else
      #   user_attrs_from_external_directory_via_dbus(username)
      # end
    end

    def user_attrs_from_external_directory_via_auth_api(username)
      conn = Faraday.new(:url => "http://httpd:4100") do |faraday|
        faraday.request(:url_encoded)               # form-encode POST params
        faraday.adapter(Faraday.default_adapter)    # make requests with Net::HTTP
      end

      begin
        response = conn.run_request(:get, "/GetUserAttr", nil, nil) do |req|
          req.headers[:content_type] = "application/json"
          req.headers[:accept]       = "application/json"
          req.params.merge!("user" => username)
        end
      rescue => err
        raise("Failed to connect to the httpd container Authentication API service - #{err}")
      end

      if response.body
        body = JSON.parse(response.body.strip)
      end

      raise(body["error"]) if response.status >= 400
      body["result"]
    end

    def user_attrs_from_external_directory_via_dbus(username)
      return unless username
      require "dbus"

      attrs_needed = %w(mail givenname sn displayname)

      sysbus = DBus.system_bus
      ifp_service   = sysbus["org.freedesktop.sssd.infopipe"]
      ifp_object    = ifp_service.object "/org/freedesktop/sssd/infopipe"
      ifp_object.introspect
      ifp_interface = ifp_object["org.freedesktop.sssd.infopipe"]
      begin
        user_attrs = ifp_interface.GetUserAttr(username, attrs_needed).first
      rescue => err
        raise _("Unable to get attributes for external user %{user_name} - %{error}") %
              {:user_name => username, :error => err}
      end

      attrs_needed.each_with_object({}) { |attr, hash| hash[attr] = Array(user_attrs[attr]).first }
    end
  end
end
