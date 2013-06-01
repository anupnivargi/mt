source "http://rubygems.org"

gem "sinatra"

gem "data_mapper"
gem "rack-flash3", :require => "rack-flash"

group :production do
  gem "pg"
  gem "dm-postgres-adapter"
end

gem "omniauth-google-oauth2"

group :development do
  gem "shotgun"
  gem "dm-sqlite-adapter"
end
