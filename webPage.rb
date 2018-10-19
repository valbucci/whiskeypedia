# Project by Andrei Rotariu and Valerio Bucci
# Template modified from WAD course practicals.

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
	property :codeLog, Integer, :required => true, :unique => true
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

	def superprotected!
		if admin?
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

	def admin?
		if $credentials != nil
			@Userz = User.first(:username => $credentials[0])
			if @Userz
				if @Userz.username == "Admin"
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
	return info
end

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
end

#Goes through each character (counting them) and stop counting during html tags.

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
	#Counts words. Uses spaces to count words.
	$words = article.split(' ').length
	$char = char
end

=begin
def replace(file = "reset.txt")
	This part was for switching between 2 text files rather than the database
	[ UPGRADED to DATABASE ]

	# Replaces file_2 with file_1.
	info = ""
	original = File.open(file_1)
	original.each do |line|
		info = info + line
	end
	original.close
	@info = info

	replace = File.open(file_2, "w")
	replace.truncate(0)
	#truncate(0) makes the filesize 0. Effectively clear.
	replace.puts @info
	replace.close
end
=end

# get the common parts of two strings
# e.g. diffHighlight("Hello", "Helno") --> Hel<u class="highlight">n</u>o
def diffHighlight(bef, aft)
	if bef == nil
		bef = ""
	end
	i = 0
	# string to be prepared
	str = ""
	# highlight opened helper
	highlight = false
	# check from left to right for differences
	while i < aft.length
		if i < bef.length and bef[i] == aft[i]
			if highlight
				highlight = false
				str += '</u>'
			end
			str += bef[i]
		else
			if highlight
				str += aft[i]
			else
				highlight = true
				str += '<u class="highlight">'+aft[i]
			end
		end
		i += 1
	end
	if highlight
		str += '</u>'
	end
=begin
	# check again from right to left
	equals = false
	html = false
	while i > 0
		# check if I'm in a html tag
		if str[i] == ">"
			html = true
		elsif str[i] == "<"
			html = false

		# I don't want to compare html code to the original string
		if !html
			if i < bef.length
				if (bef[i] == str[i]) == equals
					str.insert(i-1, )
				end
				i -= 1
			end
		end
	end
=end
	return str
end

get '/' do
	# readFile("wiki.txt")
	lastRecord = History.all(:order => :id.desc)[0];
	if lastRecord != nil
		last = lastRecord.text
	else
		last = "Uh oh... It seems like there is no content yet."
	end
	len = count_characters(last)
	@info = last
	@characters = $char.to_s
	@words = $words.to_s
	erb :home
end

get '/about' do
	erb :about
end

get '/edit' do
	protected!

	lastRecord = History.all(:order => :id.desc)[0]
	if lastRecord != nil
		last = lastRecord.text
	else
		last = ""
	end
	@info = last
	erb :edit
end

put '/edit' do
	protected!

	@info = "#{params[:message]}"
	lastRecord = History.all(:order => :id.desc)[0]
	if lastRecord != nil
		last = lastRecord.text
	else
		last = ""
	end
	if @info != last
		log = Log.new
		log.codeUser = $userData[:id]
		log.date = Time.now
		log.event = "EDIT"
		log.save

		his = History.new
		his.codeLog = log.id
		his.text = @info
		his.save
	end
	redirect '/edit'
end

get '/reset' do
	protected!
	# reset to the default text
	lastRecord = History.all(:order => :id.desc)[0]
	if lastRecord != nil
		last = lastRecord.text
	else
		last = ""
	end

	replace = readFile("reset.txt")

	if replace != last
		log = Log.new
		log.codeUser = $userData[:id]
		log.date = Time.now
		log.event = "EDIT"
		log.save

		his = History.new
		his.codeLog = log.id
		his.text = replace
		his.save
	end
	redirect '/edit'
end

get '/makedefault' do
	protected!
	# Makes replace actual default text with the last change
	## Any changes must be updated before make default.
	lastRecord = History.all(:order => :id.desc)[0]
	if lastRecord != nil
		last = lastRecord.text
	else
		last = ""
	end
	@info = last

	replace = File.open("reset.txt", "w")
	replace.truncate(0)
	replace.puts @info
	replace.close
	redirect '/edit'
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
			history = History.first(:codeLog => log.id)
			# when an history record is removed we still want to keep the log so sometimes the result will be "nil"
			if history != nil
				# add all informations to the list
				@his.push(:id => history.id, :date => log.date)
			end
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
	superprotected!
	logs = Log.all :order => :id.desc
	@joined = joinLogUser(logs)
	erb :logs
end

get '/logs/:uzer' do
	superprotected!
	user = User.first(:username => params[:uzer])
	if user != nil
		logs = Log.all(:codeUser => user.id, :order => :id.desc)
		@joined = joinLogUser(logs)
	else
		redirect '/logs'
	end
	erb :logs
end

get '/history' do
	history = History.all(:order => :id.desc)
	@his = []
	history.each do |e|
		log = Log.first(:id => e.codeLog)
		user = User.first(:id => log.codeUser)
		@his.push(:id => e.id, :date => log.date, :user => user.username)
	end
	erb :history
end

get '/history/:id' do
	text = History.first(:id => params[:id])
	if text != nil
		log = Log.first(:id => text.codeLog)
		date = log.date
		user = User.first(:id => log.codeUser)
		# store the article before the user edited it
		prev = History.first(:id => History.max(:id, :id.lt => text.id))
		previd = History.max(:id, :id.lt => text.id)
		nxt = History.min(:id, :id.gt => text.id)
		if prev != nil
			prevtext = prev.text
		else
			prevtext = ""
		end
		diff = diffHighlight(prevtext, text.text)
		@his = {:username => user.username, :tid => text.id, :date => date, :diff => diff, :previous => previd, :next => nxt}
		erb :editLog
	else
		redirect '/history/'+History.max(:id).to_s
	end
end

get '/restore/:id' do
	superprotected!
	toRes = History.first(:id => params[:id])
	if toRes != nil
		text = toRes.text
		toTrash = History.all(:id.gt => toRes.id)
		toTrash.destroy

		replace = File.open("wiki.txt", "w")
		replace.truncate(0)
		replace.puts text
		replace.close
	end
	redirect '/'
end

get '/denied' do
	erb :denied
end

not_found do
	status 404
	erb :notfound
end
