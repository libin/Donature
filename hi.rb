require 'rubygems'
require 'sinatra'

require 'lib/yellowapi'

require 'uri'
require 'JSON'

require 'erb'

require 'oauth'
require 'oauth/signature/plaintext'
require 'ruby-freshbooks'

enable :sessions

get '/' do
  erb :index
end

post '/freshbooks' do
  session[:what] = params[:what]
  session[:where] = params[:where]
  session[:howmuch] = params[:howmuch]
  
  normalized_site = "https://abc.freshbooks.com"
  oauth_key = 'abc'
  oauth_secret = '123'
  
  consumer = OAuth::Consumer.new(oauth_key, oauth_secret,
			 {
			   :site => normalized_site,
			   :request_token_path => '/oauth/oauth_request.php',
			   :access_token_path => '/oauth/oauth_access.php',
			   :authorize_path => '/oauth/oauth_authorize.php',
			   :signature_method => 'PLAINTEXT'
			 })
  request_token = consumer.get_request_token(:oauth_callback => "http://#{@env['HTTP_HOST']}/query")
  session["request_token"] = request_token
		    
  redirect request_token.authorize_url
end

get '/query' do
  request_token =  session["request_token"]
  access_token = request_token.get_access_token(:oauth_verifier => params['oauth_verifier'])
  c = FreshBooks::Client.new('abc.freshbooks.com', access_token.consumer.key, 
      access_token.consumer.secret, access_token.token, access_token.secret)
  
  y = YellowAPI.new "123", true, "JSON"
  y_r = y.find_business(session[:what], session[:where], "donature", 1, 5)
  puts y_r
  yellow = JSON.parse(y_r)["listings"]
  yellow.each do |business|
    name = business["name"]
    id = business["id"]
    prov = business["address"]["prov"]
    details = JSON.parse(y.get_business_details(prov, "b", id, "donature"))
    
    url = URI.parse(details["products"]["webUrl"][0])
    email = "info@" + url.host.gsub('www.', '').strip
    
    api_response = c.client.create :client => {:first_name => name, :last_name => name, :organization => name, :email => email}
    client_id = api_response['client_id']
    api_response = c.invoice.create :invoice => {:client_id => client_id,
                                  :notes => 'Thank you for CHOOSING to support us. The future is in your hands.',
                                  :lines => [{:line => 
                                    {:name => 'Donation', 
                                     :unit_cost => session[:howmuch][/[\d\.]+/], 
                                     :quantity => 1,
                                     :description => 'Campaign Donation'}}]}
    
  end

  erb :results
end