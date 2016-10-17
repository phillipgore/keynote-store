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
require 'pony'
require 'rack/ssl'
require 'dotenv'

require './models'
require './app'

class TheKeynoteStore < Sinatra::Base

	Dotenv.load

	configure :production, :development do
		set :app_file, __FILE__
		set :port, ENV['PORT']
		set :public_folder, File.dirname(__FILE__) + '/public'
		use Rack::Session::Pool, :expire_after => 2592000
		use Rack::SSL
		register Sinatra::Flash
		enable :logging
	end

	helpers do
		include Rack::Utils
		alias_method :h, :escape_html
	end

	before do
		@theme = Theme.all(:order => [ :list_order.asc ])
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

	not_found do
		@heading = "Whoops!"
		erb :not_found
	end

	error do
		"Y U NO WORK?"
	end



# Theme Site
	get '/' do
		@heading = "Welcome."
		erb :home
	end

	get '/catalogue' do
		@heading = "Our Themes."
		erb :catalogue
	end

	get '/key/five/:id' do
		@current_theme = Theme.get(params[:id])
		@heading = "Our Themes."
		erb :five
	end

	get '/checkout' do
		@heading = "Your Order."
		@order_number = rand(1000000000000000..9999999999999999)
		erb :checkout
	end

	post '/payment' do
		begin
			@order =  Order.new(params[:order])
			if @order.save
				Stripe.api_key = ENV['STRIPE_API_KEY']
				logger.info  "PHILLIP GORE - Stripe api_key: #{ENV['STRIPE_API_KEY']}"
				@charge = Stripe::Charge.create(
				  :amount => @amount,
				  :currency => "usd",
				  :card => @order.stripe_token,
				  :description => @order.order_email
				)
				@purchase_hash.each do |key, value|
					@theme = Theme.get(key.to_i)
					logger.info  "PHILLIP GORE - AWS access_key_id: #{ENV['AWS_ACCESS_KEY_ID']}"
					logger.info  "PHILLIP GORE - AWS secret_access_key: #{ENV['AWS_SECRET_ACCESS_KEY']}"
					logger.info  "PHILLIP GORE - AWS bucket: #{ENV['AWS_BUCKET']}"
					Aws.config.update({
					  region: 'us-west-1',
					  credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
					})
					@s3 = Aws::S3::Resource.new
					@bucket = @s3.bucket('keynote_themes')
					@object = @bucket.object("#{@theme.name.downcase.gsub(" ", "-")}.zip")
					@url = @object.presigned_url(:get, expires_in: 86400)
					
					@purchase = @order.purchases.create(
						:item_name => @theme.name,
						:item_id => @theme.id,
						:item_quantity => value.to_i,
						:item_price => @theme.price,
						:item_url => @url
					)
				end
				Pony.mail(
			      :from => 'The Keynote Store <sales@keynotestore.com>',
			      :to => "#{@order.order_email}",
			      :via => :smtp,
			      :via_options => {
			        :address              => 'smtp.sendgrid.net',
			        :port                 => '587',
			        :enable_starttls_auto => true,
			        :user_name            => ENV['USER_NAME'],
			        :password             => ENV['PASSWORD'],
			        :authentication       => :plain,
			        :domain               => 'www.keynotestore.com'
			      },
			      :subject => 'Your order from The Keynote Store. Thanks!',
			      :html_body => "<table width='600' align='center' style='font-family: Arial, Helvetica, sans-serif; font-size: 14px; color: #666; line-height: 26px; text-align: justify;'>
			      	<tr style='font-family: Garamond, Georgia, Times, serif; color: black; font-size: 24px'>
			      		<td>#{@order.order_first_name},</td>
			      	</tr>
			      	<tr>
			      		<td><img src='https://s3.amazonaws.com/keynote_store/spacer.png'></td>
			      	</tr>
			      	<tr>
			      		<td>You can view your receipt and download your order through the button below. You will only be able to download your order for 24 hours from the time of purchase.</td>
			      	</tr>
			      	<tr>
			      		<td><img src='https://s3.amazonaws.com/keynote_store/spacer.png'></td>
			      	</tr>
			      	<tr>
			      		<td><a href='http://www.keynotestore.com/order/#{@order.order_number}/#{@order.id}'><img width='143' height='30' src='https://s3.amazonaws.com/keynote_store/button-email-order@2x.png' alt='Your Order.'></a></td>
			      	</tr>
			      	<tr>
			      		<td><img src='https://s3.amazonaws.com/keynote_store/spacer.png'></td>
			      	</tr>
			      	<tr>
			      		<td>We truly appreciate your business. If you need any assistance now or in the future please contact us at <a style='color: #1E4CB1; text-decoration: none;' href='mailto:sales@keynotestore.com?Subject=Keynote%20Theme%20Support'>support@keynotestore.com</a>.</td>
			      	</tr>
			      	<tr>
			      		<td><img src='https://s3.amazonaws.com/keynote_store/spacer.png'></td>
			      	</tr>
			      	<tr>
			      		<td style='font-family: Garamond, Georgia, Times, serif; color: black; font-size: 24px'>Thank You!</td>
			      	</tr>
			      	<tr>
			      		<td>The Keynote Store</td>
			      	</tr>
			      	<tr>
			      		<td><img src='https://s3.amazonaws.com/keynote_store/spacer.png'></td>
			      	</tr>
			      	<tr>
			      		<td><img src='https://s3.amazonaws.com/keynote_store/spacer.png'></td>
			      	</tr>
			      </table>",
		      )
				      logger.info  "PHILLIP GORE - Pony user_name: #{ENV['USER_NAME']}"
				      logger.info  "PHILLIP GORE - Pony password: #{ENV['PASSWORD']}"
				session['purchase'] = nil
				redirect "/order/#{@order.order_number}/#{@order.id}"
			end
		rescue Stripe::StripeError => e
			logger.info  "PHILLIP GORE - Stripe Error: #{e.message}"
			flash.next[:notice] = "Sorry. #{e.message}"
			redirect '/checkout'
		end
	end

	get '/order/:number/:id' do
		@heading = "Thank You."
		@order = Order.get(params[:id])
		@purchase = @order.purchases.all(:order => [ :created_at.desc ])
		erb :order_summary
	end

	get '/print/order/:id' do
		@heading = "Thank You."
		@order = Order.get(params[:id])
		@purchase = @order.purchases.all(:order => [ :created_at.desc ])
		erb :print_order_summary, :layout => false
	end

	get '/free' do
		@heading = "Help Yourself."
		erb :freebies
	end

	get '/tutorials' do
		@heading = "Tips & Tricks."
		erb :tutorials
	end

	get '/support' do
		@heading = "Get Some Help."
		erb :support
	end

	get '/theme/:id' do
		@current_theme = Theme.get(params[:id])
		@heading_selector = Random.rand(8)
		@heading_array = ["Good Choice.", "Great Pick.", "Nice Thinking.", "We Agree.", "Love it.", "Yes.", "Awesome.", "Great Idea."]
		@heading = @heading_array[@heading_selector]
		if @current_theme.id === 49
			redirect "/"
		else
			erb :theme
		end
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

	post '/admin/update/theme/:id' do
		@theme = Theme.get(params[:id])
		@theme.update(params[:theme])
		if @theme.save
			redirect "/admin/edit"
		else
			flash.now[:notice] = '<div id="flash">Hmm - Something went wrong. Better try again.</div>'
		end
		@heading = "Add A Theme."
		@theme = Theme.all()
		erb :admin_edit, :layout => :admin
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
		@order = Order.all(:order => [ :created_at.desc ])
		erb :admin_orders, :layout => :admin
	end

#	get '/admin/delete/order/:id' do
#		@order = Order.get(params[:id]).destroy!
#		redirect "/admin/orders"
#	end

	get '/admin/receipt/:id' do
		@heading = "Review Receipt."
		@order = Order.get(params[:id])
		@purchase = @order.purchases.all(:order => [ :created_at.desc ])
		erb :admin_receipt, :layout => :admin
	end



	TheKeynoteStore.run!
end
