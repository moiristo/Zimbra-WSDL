gem 'soap4r'
require 'soap/header/simplehandler'
require 'defaultDriver.rb'

module ZimbraServiceDriver
  class Zimbra
    def self.create_zimbra_account
      # Initializes the driver. Don't cache this, as we need to add a new authToken to the SOAP headers.
      app_driver = AppPort.new("https://example.com:7071/service/admin/soap")
      # app_driver.options['protocol.http.ssl_config.verify_mode'] = OpenSSL::SSL::VERIFY_NONE
      app_driver.wiredump_dev = STDOUT

      # === Authenticate on Zimbra Server, remember auth token ===
      session = app_driver.authRequest('name' => 'username', 'password'=> 'the_password')
      app_driver.headerhandler << ZimbraServiceDriver::Zimbra::ZimbraContextHeader.new(Context.new(session.authToken, session.sessionId))

      # === Create Domain Request ===
      app_driver.createDomainRequest(CreateDomainRequest.new('example.com'))

      # === Create Account Request ===
      app_driver.createAccountRequest(
        CreateAccountRequest.new(
          'test@example.com',
          'password',
          [ attribute('givenName', 'John'),
            attribute('sn', 'Doe'),
            attribute('displayName', 'john_doe'),
            attribute('zimbraIsDelegatedAdminAccount', 'TRUE')
          ]
        )
      )

      # === Granting Admin Rights ===
      app_driver.grantRightRequest(
        GrantRightRequest.new(
          right_attribute('example.com', ByIdOrName::Name, TypeDomainOrUser::Domain),
          right_attribute('test@example.com', ByIdOrName::Name, TypeDomainOrUser::Usr),
          'domainAdminConsoleRights'
        )
      )

      # === Get Zimbra ID of DomainAdmins Distribution List ===
      dist_list_req = DistributionListRequest.new('zimbradomainadmins@www.zimbralogin.com')
      dist_list_req.xmlattr_by = ByIdOrName::Name
      dist_list = app_driver.getDistributionListRequest(GetDistributionListRequest.new(dist_list_req))
      zimbra_id = dist_list.dl.xmlattr_id

      # === Assigning domainAdmins DL to the created user ===
      dist_list_req = AddDistributionListMemberRequest.new(zimbra_id, 'test@example.com')
      app_driver.addDistributionListMemberRequest(dist_list_req)

      # === Done ===
    end

  private

    def self.right_attribute(value, by, type)
      r = RightRequest.new(value)
      r.xmlattr_by = by
      r.xmlattr_type = type
      return r
    end

    def self.attribute(name, value)
      a = A.new value
      a.xmlattr_n = name
      return a
    end

    class ZimbraContextHeader < SOAP::Header::SimpleHandler

      def initialize(context)
        @context = context
        super(XSD::QName.new("urn:zimbra", 'context'))
      end

      def on_simple_outbound
        { "authToken" => @context.authToken }
      end
    end
  end
end

