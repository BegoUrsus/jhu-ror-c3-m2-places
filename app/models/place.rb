class Place
  require 'pp'
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

  # Class method `find_by_short_name` that will return a `Mongo::Collection::View`
  # with a query to match documents with a matching `short_name` within `address_components`. 
  # This method must:
  #     * accept a String input parameter
  #     * find all documents in the `places` collection with a matching 
  #       `address_components.short_name`
  #     * return the `Mongo::Collection::View` result
  def self.find_by_short_name(short_name) 
    collection.find(:'address_components.short_name' => short_name)
  end

  # Helper class method `to_places` that will accept a `Mongo::Collection::View` 
  # and return a collection of `Place` instances. This method must:
  #     * accept an input parameter
  #     * iterate over contents of that input parameter
  #     * change each document hash to a Place instance (**Hint**: `Place.new`)
  #     * return a collection of results containing `Place` objects
  def self.to_places(places) 
    places.map { |p| Place.new(p) }
  end

  # Class method `find` that will return an instance of `Place` for a supplied `id`.
  # This method must:
  #     * accept a single String `id` as an argument
  #     * convert the `id` to `BSON::ObjectId` form (**Hint**: `BSON::ObjectId.from_string(s)`)
  #     * find the document that matches the `id`
  #     * return an instance of `Place` initialized with the document if found (Hint: `Place.new`)
  def self.find(id)
    id = BSON::ObjectId.from_string(id)
    doc = collection.find(:_id => id).first
    return doc.nil? ? nil : Place.new(doc)
  end

  # Class method called `all` that will return an instance 
  # of all documents as `Place` instances.
  # This method must:
  #     * accept two optional arguments: `offset` and `limit` in that order. 
  #       `offset` must default to no offset and `limit` must default to no limit
  #     * locate all documents within the `places` collection within paging limits
  #     * return each document as in instance of a `Place` within a collection  
  def self.all(offset = 0, limit = nil)
    docs = collection.find({})
      .skip(offset)
    docs = docs.limit(limit) if !limit.nil?
    docs = to_places(docs)
  end

  # Instance method `destroy` in the `Place` model class
  # that will delete the document associtiated with its assigned `id`. This 
  # method must:
  #     * accept no arguments
  #     * delete the document from the `places` collection that has an `_id` associated with
  #     the `id` of the instance  
  def destroy
    id = BSON::ObjectId.from_string(@id);
    self.class.collection.delete_one(:_id => id)
  end

  ########################################################################
  # Aggregation Framework Queries
  ########################################################################  

  # Class method `get_address_components` that returns a collection of 
  # hash documents with `address_components` and their associated 
  # `_id`, `formatted_address` and `location` properties. 
  # Your method must:
  #     * accept optional `sort`, `offset`, and `limit` parameters
  #     * extract all `address_component` elements within each document  
  #       contained withinthe collection (**Hint**: `$unwind`)
  #     * return only the `_id`, `address_components`, `formatted_address`, 
  #       and `geometry.geolocation` elements (Hint: `$project`)
  #     * apply a provided `sort` or no sort if not provided 
  #       (Hint: `$sort` and `q.pipeline` method)
  #     * apply a provided `offset` or no offset if not provided 
  #       (Hint: `$skip` and `q.pipeline` method)
  #     * apply a provided `limit` or no limit if not provided 
  #       (Hint: `$limit` and `q.pipeline` method)
  #     * return the result of the above query 
  #       (Hint: `collection.find.aggregate(...)`)
  def self.get_address_components(sort = nil, offset = 0, limit = 0)
    pline = [
      { :$unwind => "$address_components" },
      {
        :$project => {
          :_id => 1, 
          :address_components => 1, 
          :formatted_address => 1, 
          :'geometry.geolocation' => 1 }
      }
    ]
    pline.push({:$sort=>sort}) if !sort.nil?
    pline.push({:$skip=>offset}) if offset != 0
    pline.push({:$limit=>limit}) if limit != 0
    collection.find.aggregate(pline)  
  end

  # Class method `get_country_names` that returns a distinct collection of 
  # country names (`long_names`). Your method must:
  #     * accept no arguments
  #     * create separate documents for `address_components.long_name` 
  #       and `address_components.types` (Hint: `$project` and `$unwind`)
  #     * select only those documents that have a `address_components.types` element 
  #       equal to `"country"` (Hint: `$match`)
  #     * form a distinct list based on `address_components.long_name` (Hint: `$group`)
  #     * return a simple collection of just the country names (`long_name`). 
  #       You will have to use application code to do this last step. 
  #       (Hint: `.to_a.map {|h| h[:_id]}`)
  def self.get_country_names
    pline = [
      { :$unwind => '$address_components' },
      {
        :$project => {
          :'address_components.long_name' => 1,
          :'address_components.types' => 1
        }
      },
      { :$match => { :"address_components.types" => "country" } },
      { :$group => { :"_id" => '$address_components.long_name' } }
    ]
    docs = collection.find.aggregate(pline)
    
    docs.to_a.map {|h| h[:_id]}
  end

  # Class method `find_ids_by_country_code` that will return the `id` of each
  # document in the `places` collection that has 
  # an `address_component.short_name` of type `country`
  # and matches the provided parameter. This method must:
  #     * accept a single `country_code` parameter
  #     * locate each `address_component` with a matching `short_name` 
  #       being tagged with the `country` type (Hint: `$match`)
  #     * return only the `_id` property from the database (Hint: `$project`)
  #     * return only a collection of `_id`s converted to Strings 
  #       (Hint: `.map {|doc| doc[:_id].to_s}`)
  def self.find_ids_by_country_code(country_code)
    pline = [
      { :$match => {
        :'address_components.types' => "country",
        :'address_components.short_name' => country_code
        }
      },
      { :$project => { :_id => 1 } }
    ]

    collection.find.aggregate(pline).to_a.map { |doc| doc[:_id].to_s }
  end

end  
