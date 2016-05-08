class Place
  # properties
  #  * a read/write (String) attribute called `id`
  #  * a read/write (String) attribute called `formatted_address`
  #  * a read/write (Point) attribute called `location`
  #  * a read/write (collection of AddressComponents) attribute called `address_components`
  attr_accessor :id, :formatted_address, :location, :address_components

  # `initialize` that can set the attributes from a hash 
  # with keys `_id`, `address_components`, `formatted_address`, and `geometry.geolocation`. 
  # (**Hint**: use `.to_s` to convert a `BSON::ObjectId` to a `String` 
  # and `BSON::ObjectId.from_string(s)` to convert it back again.)
  def initialize(params={}) 
    @id = params[:_id].to_s
    @formatted_address = params[:formatted_address]
    @location = Point.new(params[:geometry][:geolocation])
    @address_components = params[:address_components]
      .map{ |a| AddressComponent.new(a) if !params[:address_components].nil?}
  end

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

  ########################################################################
  # Standard Queries
  ########################################################################

  # Class method called `find_by_short_name` that will return a `Mongo::Collection::View`
  # with a query to match documents with a matching `short_name` within `address_components`. 
  # This method must:
  #     * accept a String input parameter
  #     * find all documents in the `places` collection with a matching 
  #       `address_components.short_name`
  #     * return the `Mongo::Collection::View` result
  def self.find_by_short_name(short_name) 
    collection.find(:'address_components.short_name' => short_name)
  end

  # Helper class method called `to_places` that will accept a `Mongo::Collection::View` 
  # and return a collection of `Place` instances. This method must:
  #     * accept an input parameter
  #     * iterate over contents of that input parameter
  #     * change each document hash to a Place instance (**Hint**: `Place.new`)
  #     * return a collection of results containing `Place` objects
  def self.to_places(places) 
    places.map { |p| Place.new(p) }
  end

end  
