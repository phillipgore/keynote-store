DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/keynote-store.db")


class User
	include DataMapper::Resource

	property :id, 					Serial
	
	property :user_first_name,		String, 	:required => true
	property :user_last_name,		String, 	:required => true
	property :user_email,			String, 	:required => true, :unique => true, :format => :email_address
	property :password,				BCryptHash, :required => true, :length => 255

end


class Theme
  include DataMapper::Resource

	property :id, 				Serial
	
	property :created_at,		DateTime
	property :name,				String
	property :tagline,			String
	property :price,			Integer
	property :style,			Text
	property :extras,			Text
	property :keynote_version,	String
	property :fonts,			String
	property :download_size,	String
	property :theme_sizes,		String
	property :text_layouts,		String
	property :photo_layouts,	String
	property :total_layouts,	String
	property :extras_slides,	String
	property :video_tutorial,	String
	property :promo_one,		Integer
	property :promo_two,		Integer
	property :promo_three,		Integer

end


class Order
  include DataMapper::Resource

	property :id, 					Serial
	
	property :created_at,			DateTime
	property :order_number,			Integer, :length => 50
	property :order_first_name,		String
	property :order_last_name,		String
	property :order_email,			String
	property :order_newsletter,		Boolean
	property :order_discount,		Float, :default => 0
	property :order_total,			Integer
	property :stripe_token,			String
	
	has n, :purchases
	
end


class Purchase
  include DataMapper::Resource

	property :id, 				Serial
	
	property :created_at,		DateTime
	property :item_name, 		String
	property :item_id, 			Integer
	property :item_quantity, 	Integer
	property :item_price, 		Integer
	
	belongs_to :order

end



DataMapper.auto_upgrade!