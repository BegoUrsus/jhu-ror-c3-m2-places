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

  # class method called `load_all` that will bulk load a JSON document with 
  # 'places' information into the places collection. This method must
  # * accept a parameter of type `IO` with a JSON string of data
  # * read the data from that input parameter (Note: this is similar handling an uploaded
  # file within Rails)
  # * parse the JSON string into an array of Ruby hash objects representing places 
  # (Hint: `JSON.parse`)
  # * insert the array of hash objects into the `places collection` (Hint: `insert_many`)
  def self.load_all(file)
  	docs = JSON.parse(file.read)
  	collection.insert_many(docs)
  end


end  
