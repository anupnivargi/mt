require "yaml"
require "./server"

if ENV['RACK_ENV'] == "development"
  $config = YAML.load_file("config/config.yml")[ENV['RACK_ENV']]
else
  $config = {'client_id' => ENV['GOOGLE_CLIENT_ID'], 'client_secret' => ENV['GOOGLE_CLIENT_SECRET']}
end

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

use Rack::Session::Cookie, :key => "_monet", :secret => "dsdhjsakjk24423wksdkjddsadjk23j23", :path => "/", :expire_after => 86400

use OmniAuth::Builder do
  provider :google_oauth2, $config['client_id'], $config['client_secret'], { :scope => "userinfo.email,userinfo.profile", :approval_prompt => "auto" }
end

run Sinatra::Application
