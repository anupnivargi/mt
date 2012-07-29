require "sinatra"
require "dm-core"
require "dm-timestamps"
require "dm-migrations"
require "dm-validations"
require "rack-flash"
require "bcrypt"

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
  property :email, String, length: 50
  property :first_name, String, length: 50
  property :last_name, String, length: 50
  property :password_salt, String, length: 100
  property :password_hash, String, length: 100

  has n, :entries

  validates_presence_of :email, :first_name, :last_name

  validates_confirmation_of :password

  validates_presence_of :password, :if => :new?

  validates_uniqueness_of :email

  before :save, :encrypt_password

  def self.authenticate(email, clear_password)
    user = User.first(:email => email)
    if user && user.password_hash == BCrypt::Engine.hash_secret(clear_password, user.password_salt)
      user
    else
      nil
    end
  end

  def encrypt_password
    if !password.nil?
      self.password_salt = BCrypt::Engine.generate_salt
      self.password_hash = BCrypt::Engine.hash_secret(password, password_salt)
    end
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

end

DataMapper.auto_upgrade!

before do
  $DEBUG = false
  unless ['/login', "/users/create"].include?(action)
    unless authenticated?
      flash[:alert] = "Please Login or Sign Up"
      redirect "/login"
    end
  end
end


get "/" do
  @entry = Entry.new
  @entries = current_user.entries
  erb :index
end

post "/" do
  @entry = Entry.new(params[:entry])
  @entry.user_id = current_user.id
  if @entry.save
    flash[:notice] = "Entry added successfully"
    redirect "/"
  else
    @entries = current_user.entries
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
  @user = User.new
  erb :login
end

post "/login" do
  if user = User.authenticate(params[:email], params[:password])
    session[:user_id] = user.id
    redirect "/"
  else
    flash[:alert] = "Email or Password Incorrect"
    redirect "/login"
  end
end

get "/logout" do
  session[:user_id] = nil
  redirect "/login"
end

post "/users/create" do
  @user = User.new(params[:user])
  if @user.save
    session[:user_id] = @user.id
    redirect "/"
  else
    erb :login
  end
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
