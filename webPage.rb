# Project by Andrei Rotariu and Valerio Bucci

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
	property :date, DateTime
	property :event, Text, :required => true
end

class History
	include DataMapper::Resource
	property :id, Serial
	property :codeLog, Integer, :required => true
	property :text, Text, :required => true
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

<<<<<<< HEAD
def joinLogUser(logs)
	# start by getting user table
	users = User.all
	# instance of empty array that will contain the joined results
	join = [];
	# using a temporary variable to reduce the number of calls to the database
	prevId = nil
	# I will be using another variable to store names so if there are repeating logs about a single user
	# the database will be only called once
	uname = nil
	# join the two tables
	logs.each do |log|
		userId = log.codeUser
		# if the user is the same as before there's no need to call the database
		if userId != prevId
			uname = users.first(:id => userId).username
			prevId = userId
		end
		# add everything to the array
		join.push(:id => userId, :username => uname, :date => log.date, :event => log.event)
	end

	return join
=======
def count_characters(article)
	char = 0
	html = false
	article.split('').each do |character|
		if character == "<"
			html = true
		elsif character == ">"
			html = false
		else
			if !html
				char += 1
			end
		end
	end
	$words = article.split(' ').length
	$char = char
end

def replace(file_1, file_2)
	#Replaces file_2 with file_1.
	info = ""
	original = File.open(file_1)
	original.each do |line|
		info = info + line
	end
	original.close
	@info = info

	replace = File.open(file_2, "w")
	replace.truncate(0)
	replace.puts @info
	replace.close
>>>>>>> origin/master
end

get '/' do
	readFile("wiki.txt")
	len = count_characters($article)
	@info = $article
	@characters = $char.to_s
	@words = $words.to_s
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

	log = Log.new
	log.codeUser = $userData[:id]
	log.date = Time.now
	log.event = "EDIT"
	log.save

	his = History.new
	his.codeLog = log.id
	his.text = @info
	his.save

	redirect '/'
end

get '/reset' do
	protected!
	replace("reset.txt", "wiki.txt")

	redirect '/'
end

get '/makedefault' do
	protected!
	replace("wiki.txt", "reset.txt")
	#Any changes to wiki.txt must be updated before make default.

	redirect '/'
end

get '/login' do
	erb :login, :locals => {:wrongcredentials => false, :user => ''}
end

post '/login' do
	$credentials = [params[:username], params[:password]]
	@uname = $credentials[0]
	@Users = User.first(:username => @uname)
	if @Users
		if @Users.password == $credentials[1]
			$userData = {:id => @Users.id, :username => @Users.username, :edit => @Users.edit}
			log = Log.new
			log.codeUser = $userData[:id]
			log.date = Time.now
			log.event = "LOGGED_IN"
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
	if @Userz != nil
		# get logs from a user
		@Logs = Log.all(:codeUser => @Userz.id, :event => "EDIT")
		# retrieve edit history from all user editings
		@his = []
		@Logs.each do |log|
			# add history record linked to the log
			history = History.first(:codeLog => log.id).text
			# store the article before the user edited it
			prevLog = Log.first(:date => Log.max(:date, :date.lt => log.date, :event => "EDIT"))
			if prevLog != nil
				prevtext = History.first(:codeLog => prevLog.id).text
			else
				prevtext = ""
			end
			# add all informations to the list
			@his.push(:id => history, :log => log, :prevLog => prevLog, :date => log.date, :text => history, :prevtext => prevtext)
		end
		erb :profile
	else
		redirect '/usernotfound'
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
		log.codeUser = $userData[:id]
		log.date = Time.now
		log.event = "LOGGED_OUT"
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

get '/user/delete/:iduzer' do
	protected!

	n = User.first(:id => params[:iduzer])
	if n.username == "Admin"
		erb :denied
	else
		n.destroy
		@list2 = User.all :order => :id.desc
		erb :admincontrols
	end
end

get '/logs' do
	protected!
	logs = Log.all :order => :id.desc
	@joined = joinLogUser(logs)
	erb :logs
end

get '/logs/:uzer' do
	protected!
	user = User.first(:username => params[:uzer])
	if user != nil
		logs = Log.all(:codeUser => user.id, :order => :id.desc)
		@joined = joinLogUser(logs)
	else
		redirect '/logs'
	end
	erb :logs
end

get '/denied' do
	erb :denied
end

not_found do
	status 404
	erb :notfound
end
