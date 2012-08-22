require 'rubygems'
require 'sinatra/base'
require 'dm-core'
require 'dm-migrations'
require 'dm-timestamps'
require 'dm-types'
require 'dm-validations'
require 'bcrypt'
require 'sinatra/flash'
require 'stripe'
require 'aws-sdk'
require './models'
require './app'

class TheKeynoteStore < Sinatra::Base

	configure do
		set :app_file, __FILE__
		set :port, ENV['PORT']
		set :public_folder, File.dirname(__FILE__) + '/public'
		use Rack::Session::Pool, :expire_after => 2592000
		register Sinatra::Flash
	end
	
	helpers do
		include Rack::Utils
		alias_method :h, :escape_html
	end
	
	before do
		@theme = Theme.all(:name.not => "Complete Set", :order => [ :created_at.desc ])
		@complete_set = Theme.first(:name => "Complete Set")
		if session['purchase']
			@discount_percentage = 0.1
			@purchase_count = session['purchase'].count
			@purchase_hash = Hash.new(0)
			session['purchase'].each {|v| @purchase_hash[v] +=1 }
			@price = []
			@purchase_hash.each {|key, value|
				@price.push(Theme.get(key.to_i).price * value.to_i)
			}
			@purchase_total = @price.inject {|sum, key| sum + key }
			@purchase_discount = @purchase_total - (@purchase_total * @discount_percentage)
			if @purchase_count >= 3
				@amount = @purchase_discount.to_i * 100
			else
				@amount = @purchase_total.to_i * 100
			end
		end
	end
	
	after do
		if session['purchase']
			if session['purchase'].empty?
				session['purchase'] = nil
			end
		end
	end


	
# Theme Site
	get '/' do
		@heading = "Welcome."
		erb :index
	end
	
	get '/checkout' do
		@heading = "Your Order."
		@order_number = rand(1000000000000000..9999999999999999)
		erb :checkout
	end
		
	post '/payment' do
		@order =  Order.new(params[:order])
		if @order.save
			Stripe.api_key = "zjoWY2fW3w8kktSKUGdmAsTGUzceCB5I"
			@charge = Stripe::Charge.create(
			  :amount => @amount,
			  :currency => "usd",
			  :card => @order.stripe_token,
			  :description => @order.order_email
			)
			@purchase_hash.each do |key, value|
				@theme = Theme.get(key.to_i)
				@purchase = @order.purchases.create(
					:item_name => @theme.name,
					:item_id => @theme.id,
					:item_quantity => value.to_i,
					:item_price => @theme.price
				)
			end
			session['purchase'] = nil
			redirect "/order/#{@order.order_number}/#{@order.id}"
		end
	end
	
	get '/order/:number/:id' do
		@heading = "Thank You."
		@order = Order.get(params[:id])
		@purchase = @order.purchases.all(:order => [ :created_at.desc ])
		erb :order_summary
	end
	
	get '/download/:number/:id' do
		@order = Order.get(params[:id])
		if (@order.order_number == params[:number].to_i) && ((DateTime.now - @order.created_at) * 24).to_f < 24
			@s3 = AWS::S3.new(
				:access_key_id => 'AKIAJYQDOD2J6XAH77QQ',
				:secret_access_key => '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'
			)
			@bucket = @s3.buckets['keynote_themes']
			File.open('Cardboard.zip','wb') do |file|
				@bucket.objects['Cardboard.zip'].read do |chunk|
					file.write(chunk)
				end
			end
			send_file('Cardboard.zip', :type => 'application/octet-stream')
			File.delete('Cardboard.zip')
		end
	end
	
	get '/print/order/:id' do
		@heading = "Thank You."
		@order = Order.get(params[:id])
		@purchase = @order.purchases.all(:order => [ :created_at.desc ])
		erb :print_order_summary, :layout => false
	end
	
	get '/free' do
		erb :freebies
	end
	
	get '/support' do
		@heading = "Get Some Help."
		erb :support
	end
	
	get '/theme/complete_set' do
		@heading = "Take It All."
		erb :complete
	end
	
	get '/theme/:id' do
		@theme = Theme.get(params[:id])
		@heading_selector = Random.rand(8)
		@heading_array = ["Good Choice.", "Great Pick.", "Nice Thinking.", "We Agree.", "Love it.", "Yes.", "Awesome.", "Great Idea."]
		@heading = @heading_array[@heading_selector]
		erb :theme
	end
	
	get '/buy/:id' do
		if session['purchase']
			session['purchase'].push(params[:id].to_i)
		else
			@purchase_array = []
			@purchase_array.push(params[:id].to_i)
			session['purchase'] = @purchase_array
		end
		redirect '/checkout'
	end
	
	get '/remove/:id' do
		session['purchase'].delete(params[:id].to_i)
		redirect '/checkout'
	end
	
	post '/update/:id' do
		@existing_count = session['purchase'].count(params[:id].to_i)
		@new_count = params[:new_count].to_i
		session['purchase'].delete(params[:id].to_i)
		@new_count.times{
			session['purchase'].push(params[:id].to_i)
		}	
		redirect '/checkout'
	end


	
# Admin Login
	get '/login' do
		@heading = "Login to Admin."
		erb :admin_login, :layout => :admin_alt
	end

	post '/login' do
		@user = User.first(:user_email => params[:user_email])
		if @user
			if @user.password == params[:password]
			session['user_id'] = @user.id
			session['expires'] = 86400
			redirect '/admin/edit'
		else
			flash.next[:notice] = '<div id="flash">Sorry, invalid password.</div>'
			redirect '/login'
		end
		else
			flash.next[:notice] = '<div id="flash">Sorry, invalid username.</div>'
			redirect '/login'
		end
	end
	
	get '/logout' do
		session['user_id'] = nil
		redirect '/login'
	end	


	
# Admin Site
	before '/admin/*' do
		unless session['user_id']
			redirect '/login'
		end
	end
	
	get '/admin' do
		if session['user_id']
			redirect '/admin/edit'
		else
			redirect '/login'
		end
	end
	
	get '/admin/edit' do
		@heading = "Edit A Theme."
		erb :admin_edit, :layout => :admin
	end
	
	get '/admin/edit/:id' do
		@theme = Theme.get(params[:id])
		@banner_id = "#{@theme.name}"
		@heading = "Edit #{@theme.name}."
		@sub_heading = "The Keynote Store"
		@theme_list = Theme.all()
		erb :admin_update, :layout => :admin
	end
	
	post '/admin/update/:id' do
		@update_theme = Theme.get(params[:id])
		@update_theme.update(params[:theme])
		if @update_theme.save
			redirect '/admin/edit'
		else
			flash.now[:notice] = '<div id="flash">Hmm - Something went wrong. Better try again.</div>'
		end
		@heading = "Add A Theme."
		@theme = Theme.all()
		erb :admin_update, :layout => :admin
	end
	
	get '/admin/add' do
		@heading = "Add A Theme."
		@theme = Theme.all()
		erb :admin_add, :layout => :admin
	end
	
	post '/admin/add/theme' do
		@new_theme = Theme.new(params[:theme])
		if @new_theme.save
			redirect '/admin/edit'
		else
			flash.now[:notice] = '<div id="flash">Hmm - Something went wrong. Better try again.</div>'
		end
		@heading = "Add A Theme."
		@theme = Theme.all()
		erb :admin_add, :layout => :admin
	end
	
	get '/admin/delete/:id' do
		Theme.get(params[:id]).destroy!
		redirect '/admin/edit'
	end
	
	get '/admin/users' do
		@heading = "Manage Users."
		@users = User.all(:order => [:user_last_name.asc])
		erb :admin_users, :layout => :admin
	end
	
	post '/admin/add/user' do
		@user = User.new(params[:user])
		if @user.save
			redirect '/admin/users'
		else
			flash.next[:notice] = '<div id="flash">All fields are required. Please format correctly.</div>'
			redirect "/admin/users"
		end
	end
	
	get '/admin/edit/user/:id' do
		@heading = "Update User."
		@user = User.get(params[:id])
		erb :admin_user_edit, :layout => :admin
	end
	
	post '/admin/update/user/:id' do
		@user = User.get(params[:id])
		@user.update(params[:user])
		if @user.save
			redirect "/admin/users"
		else
			flash.next[:notice] = '<div id="flash">All fields are required. Please format correctly.</div>'
			redirect "/admin/edit/user/#{@user.id}"
		end
	end
	
	get '/admin/change/password/:id' do
		@heading = "Change Password."
		@user = User.get(params[:id])
		erb :admin_user_password_edit, :layout => :admin
	end
	
	post '/admin/update/password/:id' do
		@current_user = "#{session['user_id']}"
		@user = User.get(params[:id])
		if @user.password == params[:password] 
			if params[:new_password] == params[:retype_password]
				@user = User.update(:password => params[:new_password])
				if @current_user == params[:id]
					session['user_id'] = nil
					flash.next[:notice] = '<div id="flash">New password. Please log in again.</div>'
					redirect '/login'
				else
					flash.next[:notice] = '<div id="flash">Password has been updated.</div>'
					redirect "/admin/users"
				end
			else
				flash.next[:notice] = '<div id="flash">Sorry, new passwords do not match.</div>'
				redirect "/admin/change/password/#{@user.id}"
			end
		else
			flash.next[:notice] = '<div id="flash">Sorry, invalid password.</div>'
			redirect "/admin/change/password/#{@user.id}"
		end
	end
	
	get '/admin/delete/user/:id' do
		if User.count > 1
			@user = User.get(params[:id]).destroy!
			redirect "/admin/users"
		else
			flash.next[:notice] =  '<div id="flash">You must maintain at least one user account.</div>'
			redirect "/admin/users"
		end
	end
	
	get '/admin/orders' do
		@heading = "Find Orders."
		@order = Order.all()
		erb :admin_orders, :layout => :admin
	end
	
	get '/admin/receipt/:id' do
		@heading = "Review Receipt."
		@order = Order.get(params[:id])
		@purchase = @order.purchases.all(:order => [ :created_at.desc ])
		erb :admin_receipt, :layout => :admin
	end
		
	
	
	TheKeynoteStore.run!
end