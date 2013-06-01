require "bundler"
Bundler.require :default, ENV['RACK_ENV']

enable :sessions
use Rack::Flash

configure :development do
  DataMapper.setup(:default, "sqlite://#{Dir.pwd}/noop_dev.db")
  DataMapper::Logger.new($stdout, :debug)
end

configure :production do
  DataMapper.setup(:default, ENV["DATABASE_URL"])
end

class User
  include DataMapper::Resource

  attr_accessor :password, :password_confirmation

  property :id, Serial
  property :uid, String, length: 50
  property :provider, String, length: 10
  property :email, String, length: 50
  property :first_name, String, length: 50
  property :last_name, String, length: 50

  has n, :entries

  validates_presence_of :uid, :email, :first_name, :last_name

  validates_uniqueness_of :uid, :email

  def full_name
    "#{first_name} #{last_name}"
  end

  def self.authenticate(omniauth)
    user = User.first(uid: omniauth["uid"])
    unless user
      user = User.new(uid: omniauth["uid"], email: omniauth["info"]["email"], first_name: omniauth["info"]["first_name"], last_name: omniauth["info"]["last_name"])
      user.save!
    end
    user
  end

end

class Entry
  include DataMapper::Resource

  property :id, Serial
  property :particular, String, length: 140
  property :location, String, length: 50
  property :amount, Float
  property :payment_mode, String, length: 1
  property :spent_on, DateTime
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :user

  validates_presence_of :particular, :amount

  validates_numericality_of :amount

  def amount=(amt)
    self[:amount] = amt.to_f if amt.to_f.to_s == amt || amt.to_i.to_s == amt
  end

end

DataMapper.auto_upgrade!

before do
  # $DEBUG = false
  unless ['/login', "/auth/google_oauth2/callback"].include?(action)
    unless authenticated?
      redirect "/login"
    end
  end
end

get "/" do
  @entry = Entry.new
  @entries = current_user.entries.all(:order => [:updated_at.desc], :limit => 100).group_by{ |rec| rec.updated_at.strftime('%B %Y') }
  erb :index
end

post "/" do
  @entry = Entry.new(params["entry"])
  @entry.user_id = current_user.id
  if @entry.save
    flash[:notice] = "Entry added successfully"
    redirect "/"
  else
    @entries = current_user.entries.all(:order => [:updated_at.desc]).group_by{ |rec| rec.updated_at.strftime('%B %Y') }
    erb :index
  end
end

get "/delete/:id" do
  @entry = current_user.entries.first(params[:id])
  if @entry.destroy
    flash[:notice] = "Deleted"
  else
    flash[:alert] = "Failed to Delete"
  end
  redirect "/"
end

get "/login" do
  erb :login
end

get '/auth/:provider/callback' do
  if user = User.authenticate(request.env['omniauth.auth'])
    session[:user_id] = user.id
    redirect "/"
  else
    redirect "/login"
  end
end

get '/auth/failure' do
  redirect "/"
end

get "/logout" do
  session[:user_id] = nil
  redirect "/login"
end


helpers do

  def action
    request.path
  end

  def authenticated?
    !current_user.nil?
  end

  def current_user
    @current_user ||= User.get(session[:user_id])
  end

end
