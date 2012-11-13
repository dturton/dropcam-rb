module Net
  class HTTPResponse
    def success?
      self.code.to_i == 200
    end
  end
end

module Dropcam
  require "net/https"
  require "uri"
  require "json"

  class Base
    NEXUS_API_BASE = "https://nexusapi.dropcam.com/"
    API_BASE = "https://www.dropcam.com/"
    LOGIN_PATH = "/login.login"
    API_PATH = "/api/v1"
    
    def initialize(username, password)
      @cookies = Array.new
    end
    
    def post(path, parameters, use_nexus=false)

      http = _dropcam_http(use_nexus)
      
      request = Net::HTTP::Post.new(path)
      request.set_form_data(parameters)
      
      cookies = self.get_cookies
      request.add_field("Cookie",cookies)

      response = http.request(request)
      
      return response
    end
    
    def get(path, parameters,use_nexus=false)
      http = _dropcam_http(use_nexus)
      
      cookies = self.get_cookies
      
      query_path = "#{path}?#{URI.encode_www_form(parameters)}"
      request = Net::HTTP::Get.new(query_path)      
      request.add_field("Cookie",cookies)
            
      response = http.request(request)
      return response
    end
    def cookies=(cookies)
      @cookies = cookies
    end
    def add_cookie(cookie)
      @cookies.push(cookie.split('; ')[0])
    end
    def get_cookies
      @cookies.join('; ')
    end

    private
    def _dropcam_http(use_nexus)
      base = API_BASE
      base = NEXUS_API_BASE if use_nexus
      uri = URI.parse(base)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      #http.set_debug_output($stdout)
      
      return http
    end
    
    def _login(username, password)
      params = {"username" => username, "password" => password}
      response = post(API_PATH+LOGIN_PATH, params)
      if response.success? ## for some reason, dropcam responds with 200 on invalid credentials
        all_cookies = response.get_fields('set-cookie')
        
        unless all_cookies ## only cookies are set on valid credentials
          puts "Invalid Dropcam credentials"
          exit
        end
        
        all_cookies.each { | cookie |
            add_cookie(cookie)
        }
      else
        raise "Invalid Dropcam credentials"
      end
      
      nil
    end
       
  end
  
  class API < Base
    ALL_CAMERAS_PATH = "#{API_PATH}/cameras.get_visible"
    
    def initialize(username, password)
      super
      _login(username, password)
      
    end
    
    def cameras
      response = get(ALL_CAMERAS_PATH, {"group_cameras" => true})
      cameras = []
      if response.success?
        response_json = JSON.parse(response.body)
        owned = response_json["items"][0]["owned"]
        owned.each{|camera|
          c = Camera.new(camera)
          c.cookies = @cookies
          cameras.push(c)
        }
      end
      return cameras
    end
  end
  
  class Camera < Base
    IMAGE_PATH = "/get_image"
    
    attr_reader :name, :uuid
    
    def initialize(parameters)
      @uuid = parameters["uuid"]
      @name = parameters["title"]
    end
    
    def current_image(width)
      response = get(IMAGE_PATH, {"uuid"=>@uuid, "width" => width}, true)      
      if response.success?
        return response.body
      end
      nil
    end
    
    def write_current_image(path=nil)
      image = current_image(1200)
      return false unless image
      path = "#{@name}.jpeg" unless path
      File.open(path,"wb") do |f|
        f.write image
      end
      
      return true
    end
    
  end
  
end
