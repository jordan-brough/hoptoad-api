# Ruby lib for working with the Hoptoad API's XML interface.
# The first thing you need to set is the account name.  This is the same
# as the web address for your account.
#
#   Hoptoad.account = 'myaccount'
#
# Then, you should set the authentication token.
#
#   Hoptoad.auth_token = 'abcdefg'
#
# If no token or authentication info is given, a HoptoadError exception will be raised.
#
# If your account uses ssl then turn it on:
#
#   Hoptoad.secure = true
#
# For more details, check out the hoptoad docs at http://hoptoadapp.com/pages/api.
#
# Find errors by id
#
#   error = Hoptoad::Error.find(1234)
#
# Find *all* notices by error_id
#
#   notices = Hoptoad::Notice.all(1234) # 1234 == error id
#
# Find notice by id + error_id
#
#   notice = Hoptoad::Notice.find(12345, 1234) # 12345 == notice id, 1234 == error id

module Hoptoad
  class Base
    include HTTParty
    format :xml

    class << self
      private

      def setup
        base_uri Hoptoad.account
        default_params :auth_token => Hoptoad.auth_token
        check_configuration
      end

      def check_configuration
        raise HoptoadError.new('API Token cannot be nil') if default_options.nil? || default_options[:default_params].nil? || !default_options[:default_params].has_key?(:auth_token)
        raise HoptoadError.new('Account cannot be nil') unless default_options.has_key?(:base_uri)
      end
    end
  end

  class Error < Base
    class << self
      def find(id, options={})
        setup

        response = get(find_path(id), {:query => options})
        if response.code == 403
          raise HoptoadError.new('SSL should be enabled - use Hoptoad.secure = true in configuration')
        end
        hash = Hashie::Mash.new(response)
        if hash.errors
          raise HoptoadError.new(results.errors.error)
        end

        hash.group
      end

      private

      def find_path(id)
        "/errors/#{id}.xml"
      end
    end
  end

  class Notice < Base
    class << self
      def find(id, error_id, options={})
        setup

        response = get(find_path(id, error_id), {:query => options})
        if response.code == 403
          raise HoptoadError.new('SSL should be enabled - use Hoptoad.secure = true in configuration')
        end
        hash = Hashie::Mash.new(response)
        if hash.errors
          raise HoptoadError.new(results.errors.error)
        end

        hash.notice
      end

      def all(error_id, options={})
        setup

        page = 1
        notices = []
        while true
          options[:page] = page
          hash = Hashie::Mash.new(get(all_path(error_id), {:query => options}))
          if hash.errors
            raise HoptoadError.new(results.errors.error)
          end
          notice_stubs = hash.notices

          notice_stubs.map do |notice|
            notices << find(notice.id, error_id)
            puts "found #{notices.last.id}"
          end
          break if notice_stubs.size < 30
          page += 1
        end
        notices
      end

      private

      def find_path(id, error_id)
        "/errors/#{error_id}/notices/#{id}.xml"
      end
      
      def all_path(error_id)
        "/errors/#{error_id}/notices.xml"
      end
    end
  end
end
