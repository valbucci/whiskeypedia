require "sinatra"
require "data_mapper"

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/wiki.db")

class User
	include DataMapper::Resource
	property :id, Serial
	property :username, Text, :required => true, :unique => true
	property :password, Text, :required => true
	property :date_joined, DateTime
	property :edit, Boolean, :required => true, :default => false
end

class Log
	include DataMapper::Resource
	property :id, Serial
	property :codeUser, Integer
	property :username, Text, :required => true
	property :date, DateTime
	property :loggedIn, Boolean, :required => true, :default => true
end

DataMapper.finalize.auto_upgrade!

$myinfo = "Andrei & Valerio"
@info = ""

helpers do
	def protected!
		if authorised?
			return
		end

		redirect '/denied'
	end

	def authorised?
		if $credentials != nil
			@Userz = User.first(:username => $credentials[0])
			if @Userz
				if @Userz.edit == true or @Userz.username == "Admin"
					return true
				else
					return false
				end
			else
				return false
			end
		end
	end
end

def readFile(filename)
	info = ""
	file = File.open(filename)
	file.each do |line|
		info = info + line
	end
	file.close
	$article = info
end

get '/' do
	readFile("wiki.txt")
	len = $article.length
	@info = $article
	@words = len.to_s
	erb :home
end

get '/about' do
	erb :about
end

get '/create' do
	erb :create
end

get '/edit' do
	protected!

	info = ""
	file = File.open("wiki.txt")
	file.each do |line|
		info = info + line
	end
	file.close
	@info = info
	erb :edit
end

put '/edit' do
	protected!

	info = "#{params[:message]}"
	@info = info
	file = File.open("wiki.txt", "w")
	file.puts @info
	file.close
	redirect '/'
end

get '/login' do
	erb :login, :locals => {:wrongcredentials => false, :user => ''}
end

post '/login' do
	$credentials = [params[:username], params[:password]]
	@uname = $credentials[0]
	@Users = User.first(:username => $credentials[0])
	if @Users
		if @Users.password == $credentials[1]
			$userData = {:id => @Users.id, :username => @Users.username, :edit => @Users.edit}
			log = Log.new
			log.username = $userData[:username]
			log.codeUser = $userData[:id]
			log.date = Time.now
			log.loggedIn = true
			log.save
			redirect '/'
		else
			$credentials = ['', '']
			erb :login, :locals => {:wrongcredentials => true, :user => @uname}
		end
	else
		$credentials = ['', '']
		erb :login, :locals => {:wrongcredentials => true, :user => @uname}
	end
end

get '/user/:uzer' do
	@Userz = User.first(:username => params[:uzer])
	if $userData != nil and @Userz.id == $userData[:id]
		erb :profile
	else
		redirect '/notlogged'
	end
end

get '/createaccount' do
	erb :createaccount
end

post '/createaccount' do
	n = User.new
	n.username = params[:username]
	n.password = params[:password]
	n.date_joined = Time.now
	if n.username == "Admin" and n.password == "Password"
		n.edit = true
	end
	n.save
	redirect '/'
end

get '/admincontrols' do
	protected!

	@list2 = User.all :order => :id.desc
	erb :admincontrols
end

get '/logout' do
	if $userData != nil
		log = Log.new
		log.username = $userData[:username]
		log.codeUser = $userData[:id]
		log.date = Time.now
		log.loggedIn = true
		log.save
	end
	$credentials = nil
	redirect '/'
end

get '/notlogged' do
	erb :notlogged
end

put '/user/edit' do
	index = 0
	params[:userEdit].each do |user|
		n = User.first(:id => user)
		if params[:edit] != nil and params[:edit][index] == user
			n.edit = 1
			index += 1
		else
			n.edit = 0
		end
		n.save
	end
	redirect '/admincontrols'
end

get '/user/delete/:uzer' do
	protected!

	n = User.first(:id => params[:uzer])
	if n.username == "Admin"
		erb :denied
	else
		n.destroy
		@list2 = User.all :order => :id.desc
		erb :admincontrols
	end
end

get '/denied' do
	erb :denied
end

not_found do
	status 404
	erb :notfound
end
