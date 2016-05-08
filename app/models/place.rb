class Place

  # class method called `mongo_client` that returns a MongoDB Client from Mongoid
  # referencing the default database from the `config/mongoid.yml` file 
  def self.mongo_client
  	db = Mongo::Client.new('mongodb://localhost:27017')
  end

  # class method called `collection` that returns a reference to the `places` collection
  def self.collection
  	self.mongo_client['places']
  end

end  
