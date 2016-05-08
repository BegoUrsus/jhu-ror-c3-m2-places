class Place
  include ActiveModel::Model

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
      .map{ |a| AddressComponent.new(a)} if !params[:address_components].nil? 
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

  ########################################################################
  # Geolocation Queries
  ########################################################################  

  # Class methods `create_indexes` used to create `2dsphere` index to your 
  # collection for the `geometry.geolocation` property. 
  # This method must make sure the `2dsphere` index is in place for the 
  # `geometry.geolocation` property (**Hint**: `Mongo::Index::GEO2DSPHERE`)
  #     * `remove_indexes` must make sure the `2dsphere` index is removed from the 
  #     collection (**Hint**: `Place.collection.indexes.map {|r| r[:name] }`
  #     displays the names of each index)
  def self.create_indexes
    collection.indexes.create_one(:'geometry.geolocation' => Mongo::Index::GEO2DSPHERE)
  end

  # Class methods `remove_indexes` used to remove a `2dsphere` index to your 
  # collection for the `geometry.geolocation` property. 
  # These methods must make sure the `2dsphere` index is removed from the 
  # collection (**Hint**: `Place.collection.indexes.map {|r| r[:name] }`
  # displays the names of each index)
  def self.remove_indexes
    collection.indexes.drop_one('geometry.geolocation_2dsphere')
  end

  # Class method called `near` that returns places that are closest to 
  # provided `Point`. This method must:
  #   * accept an input parameter of type `Point` and 
  #     an optional `max_meters` that defaults to no maximum
  #   * performs a `$near` search using the `2dsphere` index placed on the `geometry.geolocation`
  #     property and the `GeoJSON` output of `point.to_hash` (created earlier). 
  #     (**Hint**: [`Query a 2dsphere Index`](https://docs.mongodb.org/manual/tutorial/query-a-2dsphere-index/))
  #   * limits the maximum distance -- if provided -- in determining matches 
  #     (**Hint**: `$maxDistance`)
  #   * returns the resulting view (i.e., the result of find())
  def self.near(point, max_meters=nil)
    query = {
      :'geometry.geolocation' => {
        :$near => {
          :$geometry => point.to_hash,
          :$maxDistance => max_meters
        }
      }
    }
    collection.find(query)
  end

  #  Instance method `near` that wraps the class method 'near'
  # This method must:
  #   * accept an optional parameter that sets a maximum distance threshold in meters
  #   * locate all `places` within the specified maximum distance threshold
  #   * return the collection of matching documents as a collection of `Place` instances
  #     using the `to_places` class method added earlier.
  def near(max_meters=nil)
    if (!@location.nil?)
      self.class.to_places(self.class.near(@location, max_meters))
    end
  end

  ####################################################################
  # Relationships
  ####################################################################

  # Instance method that return a collection of `Photos` that have been associated 
  # with the place. This method must:
  #   * accept an optional set of arguments (`offset`, and `limit`) to skip into 
  #     and limit the result set. The offset should default to `0` and the limit should
  #     default to unbounded.
  def photos(offset = 0, limit = nil)
    photos = Photo.find_photos_for_place(@id).skip(offset)
    photos = photos.limit(limit) if !limit.nil?
    if photos.count
      result = photos.map { |photo| Photo.new(photo) }
    else 
      result = []
    end
    return result
  end

  ####################################################################
  # Relationships
  ####################################################################

  # `persisted?` method returns true if the model instance has been 
  #   saved to the database.  This will allow it to use the `:id` to navigate from 
  #   the index page to the show page.
  def persisted?
    !@id.nil?
  end






end  
