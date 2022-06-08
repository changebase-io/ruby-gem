require 'net/https'

module Changebase
  
  class ServerError < ::RuntimeError
  end

  # RuntimeErrors don't get translated by Rails into
  # ActiveRecord::StatementInvalid which StandardError do. Would rather
  # use StandardError, but it's usefull with Changebase to know when something
  # raises a Changebase::Exception::NotFound or Forbidden
  class Exception < ::RuntimeError
    
    class UnexpectedResponse < Changebase::Exception
    end

    class BadRequest < Changebase::Exception
    end

    class Unauthorized < Changebase::Exception
    end

    class Forbidden < Changebase::Exception
    end

    class NotFound < Changebase::Exception
    end

    class Gone < Changebase::Exception
    end

    class MovedPermanently < Changebase::Exception
    end
    
    class BadGateway < Changebase::Exception
    end

    class ApiVersionUnsupported < Changebase::Exception
    end

    class ServiceUnavailable < Changebase::Exception
    end

  end
  
end


# _Changebase::Connection_ is a low-level API. It provides basic HTTP #get,
# #post, #put, and #delete calls to the an HTTP(S) Server. It can also provides 
# basic error checking of responses.
class Changebase::Connection

  attr_reader :api_key, :host, :port, :use_ssl

  # Initialize a connection Changebase.
  #
  # Options:
  #
  # * <tt>:url</tt> - An optional url used to set the protocol, host, port,
  #   and api_key
  # * <tt>:host</tt> - The default is to connect to 127.0.0.1.
  # * <tt>:port</tt> - Defaults to 80.
  # * <tt>:use_ssl</tt> - Defaults to true.
  # * <tt>:api_key</tt> - An optional token to send in the `Api-Key` header
  # * <tt>:user_agent</tt> - An optional string. Will be joined with other
  #                          User-Agent info.
  def initialize(config)
    if config[:url]
      uri = URI.parse(config.delete(:url))
      config[:api_key] ||= (uri.user ? CGI.unescape(uri.user) : nil)
      config[:host]    ||= uri.host
      config[:port]    ||= uri.port
      config[:use_ssl] ||= (uri.scheme == 'https')
    end

    [:api_key, :host, :port, :use_ssl, :user_agent].each do |key|
      self.instance_variable_set(:"@#{key}", config[key])
    end

    @connection = Net::HTTP.new(host, port)
    @connection.max_retries         = 0
    @connection.open_timeout        = 5
    @connection.read_timeout        = 30
    @connection.write_timeout       = 5
    @connection.ssl_timeout         = 5
    @connection.keep_alive_timeout  = 30
    @connection.use_ssl = use_ssl
    true
  end

  def connect!
    @connection.start
  end

  def active?
    @connection.active?
  end

  def reconnect!
    disconnect!
    connect!
  end

  def disconnect!
    @connection.finish if @connection.active?
  end

  # Returns the User-Agent of the client. Defaults to:
  # "Rubygems/changebase@GEM_VERSION Ruby@RUBY_VERSION-pPATCH_LEVEL RUBY_PLATFORM"
  def user_agent
    [
      @user_agent,
      "Rubygems/changebase@#{Changebase::VERSION}",
      "Ruby@#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}",
      RUBY_PLATFORM
    ].compact.join(' ')
  end

  # Sends a Net::HTTPRequest to the server. The headers returned from
  # Connection#request_headers are automatically added to the request.
  # The appropriate error is raised if the response is not in the 200..299
  # range.
  #
  # Paramaters::
  #
  # * +request+ - A Net::HTTPRequest to send to the server
  # * +body+ - Optional, a String, IO Object, or a Ruby object which is
  #            converted into JSON and sent as the body
  # * +block+ - An optional block to call with the +Net::HTTPResponse+ object.
  #
  # Return Value::
  #
  #  Returns the return value of the <tt>&block</tt> if given, otherwise the
  #  response object (a Net::HTTPResponse)
  #
  # Examples:
  #
  #  #!ruby
  #  connection.send_request(#<Net::HTTP::Get>) # => #<Net::HTTP::Response>
  #
  #  connection.send_request(#<Net::HTTP::Get @path="/404">) # => raises Changebase::Exception::NotFound
  #
  #  # this will still raise an exception if the response_code is not valid
  #  # and the block will not be called
  #  connection.send_request(#<Net::HTTP::Get>) do |response|
  #    # ...
  #  end
  #
  #  # The following example shows how to stream a response:
  #  connection.send_request(#<Net::HTTP::Get>) do |response|
  #    response.read_body do |chunk|
  #      io.write(chunk)
  #    end
  #  end
  def send_request(request, body=nil, &block)
    request_headers.each { |k, v| request[k] = v }
    request['Content-Type'] ||= 'application/json'
  
    if body.is_a?(IO)
      request['Transfer-Encoding'] = 'chunked'
      request.body_stream =  body
    elsif body.is_a?(String)
      request.body = body
    elsif body
      request.body = JSON.generate(body)
    end

    return_value = nil
    begin
      close_connection = false
      @connection.request(request) do |response|
        # if response['Deprecation-Notice']
        #   ActiveSupport::Deprecation.warn(response['Deprecation-Notice'])
        # end

        validate_response_code(response)

        # Get the cookies
        response.each_header do |key, value|
          case key.downcase
          when 'connection'
            close_connection = (value == 'close')
          end
        end

        if block_given?
          return_value = yield(response)
        else
          return_value = response
        end
      end
      @connection.finish if close_connection
    end

    return_value
  end

  # Send a GET request to +path+ via +Connection#send_request+.
  # See +Connection#send_request+ for more details on how the response is
  # handled.
  #
  # Paramaters::
  #
  # * +path+ - The +path+ on the server to GET to.
  # * +params+ - Either a String, Hash, or Ruby Object that responds to
  #              #to_param. Appended on the URL as query params
  # * +block+ - An optional block to call with the +Net::HTTPResponse+ object.
  #
  # Return Value::
  #
  #  See +Connection#send_request+
  #
  # Examples:
  #
  #  #!ruby
  #  connection.get('/example') # => #<Net::HTTP::Response>
  #
  #  connection.get('/example', 'query=stuff') # => #<Net::HTTP::Response>
  #
  #  connection.get('/example', {:query => 'stuff'}) # => #<Net::HTTP::Response>
  #
  #  connection.get('/404') # => raises Changebase::Exception::NotFound
  #
  #  connection.get('/act') do |response|
  #    # ...
  #  end
  def get(path, params='', &block)
    params ||= ''
    request = Net::HTTP::Get.new(path + '?' + params.to_param)

    send_request(request, nil, &block)
  end

  # Send a POST request to +path+ via +Connection#send_request+.
  # See +Connection#send_request+ for more details on how the response is
  # handled.
  #
  # Paramaters::
  #
  # * +path+ - The +path+ on the server to POST to.
  # * +body+ - Optional, See +Connection#send_request+.
  # * +block+ - Optional, See +Connection#send_request+
  #
  # Return Value::
  #
  #  See +Connection#send_request+
  #
  # Examples:
  #
  #  #!ruby
  #  connection.post('/example') # => #<Net::HTTP::Response>
  #
  #  connection.post('/example', 'body') # => #<Net::HTTP::Response>
  #
  #  connection.post('/example', #<IO Object>) # => #<Net::HTTP::Response>
  #
  #  connection.post('/example', {:example => 'data'}) # => #<Net::HTTP::Response>
  #
  #  connection.post('/404') # => raises Changebase::Exception::NotFound
  #
  #  connection.post('/act') do |response|
  #    # ...
  #  end
  def post(path, body=nil, &block)
    request = Net::HTTP::Post.new(path)

    send_request(request, body, &block)
  end

  # Send a PUT request to +path+ via +Connection#send_request+.
  # See +Connection#send_request+ for more details on how the response is
  # handled.
  #
  # Paramaters::
  #
  # * +path+ - The +path+ on the server to POST to.
  # * +body+ - Optional, See +Connection#send_request+.
  # * +block+ - Optional, See +Connection#send_request+
  #
  # Return Value::
  #
  #  See +Connection#send_request+
  #
  # Examples:
  #
  #  #!ruby
  #  connection.put('/example') # => #<Net::HTTP::Response>
  #
  #  connection.put('/example', 'body') # => #<Net::HTTP::Response>
  #
  #  connection.put('/example', #<IO Object>) # => #<Net::HTTP::Response>
  #
  #  connection.put('/example', {:example => 'data'}) # => #<Net::HTTP::Response>
  #
  #  connection.put('/404') # => raises Changebase::Exception::NotFound
  #
  #  connection.put('/act') do |response|
  #    # ...
  #  end
  def put(path, body=nil, *valid_response_codes, &block)
    request = Net::HTTP::Put.new(path)

    send_request(request, body, &block)
  end

  # Send a DELETE request to +path+ via +Connection#send_request+.
  # See +Connection#send_request+ for more details on how the response is
  # handled
  #
  # Paramaters::
  #
  # * +path+ - The +path+ on the server to POST to.
  # * +block+ - Optional, See +Connection#send_request+
  #
  # Return Value::
  #
  #  See +Connection#send_request+
  #
  # Examples:
  #
  #  #!ruby
  #  connection.delete('/example') # => #<Net::HTTP::Response>
  #
  #  connection.delete('/404') # => raises Changebase::Exception::NotFound
  #
  #  connection.delete('/act') do |response|
  #    # ...
  #  end
  def delete(path, &block)
    request = Net::HTTP::Delete.new(path)

    send_request(request, nil, &block)
  end

  private

  def request_headers
    headers = {}
  
    headers['Accept'] = 'application/json'
    headers['User-Agent'] = user_agent
    headers['Api-Version'] = '0.2.0'
    headers['Connection'] = 'keep-alive'
    headers['Api-Key'] = api_key if api_key
  
    headers
  end

  # Raise an Changebase::Exception based on the response_code, unless the
  # response_code is include in the valid_response_codes Array
  #
  # Paramaters::
  #
  # * +response+ - The Net::HTTP::Response object
  #
  # Return Value::
  #
  #  If an exception is not raised the +response+ is returned
  #
  # Examples:
  #
  #  #!ruby
  #  connection.validate_response_code(<Net::HTTP::Response @code=200>) # => <Net::HTTP::Response @code=200>
  #
  #  connection.validate_response_code(<Net::HTTP::Response @code=404>) # => raises Changebase::Exception::NotFound
  #
  #  connection.validate_response_code(<Net::HTTP::Response @code=500>) # => raises Changebase::Exception
  def validate_response_code(response)
    code = response.code.to_i

    if !(200..299).include?(code)
      case code
      when 400
        raise Changebase::Exception::BadRequest, response.body
      when 401
        raise Changebase::Exception::Unauthorized, response.body
      when 403
        raise Changebase::Exception::Forbidden, response.body
      when 404
        raise Changebase::Exception::NotFound, response.body
      when 410
        raise Changebase::Exception::Gone, response.body
      when 422
        raise Changebase::Exception::ApiVersionUnsupported, response.body
      when 503
        raise Changebase::Exception::ServiceUnavailable, response.body
      when 301
        raise Changebase::Exception::MovedPermanently, response.body
      when 502
        raise Changebase::Exception::BadGateway, response.body
      when 500..599
        raise Changebase::ServerError, response.body
      else
        raise Changebase::Exception, response.body
      end
    end
  end
end
