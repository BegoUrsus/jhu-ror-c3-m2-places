=begin
The purpose of this model class is to encapsulate all information and content access to a 
photograph. This model uses [`GridFS`](https://docs.mongodb.org/manual/core/gridfs/) -- 
rather than a usual MongoDB collection like `places` since there will be an 
information aspect and a raw data aspect to this model type. This model class 
will also be responsible for extracting geolocation coordinates from each `photo` 
and locating the nearest `place` (within distance tolerances) to where that `photo` was taken.
To simplify the inspection of the photo image data, all photos handled by this model 
class will be assumed to be `jpeg` images.  You may use the [`exifr gem`]
(https://rubygems.org/gems/exifr/) to extract available geographic coordinates from 
each `photo`.
=end

class Photo
  include Mongoid::Document
  # attributes:
  #   * a read/write attribute called `id` that will be of type `String` to hold the 
  #   String form of the GridFS file `_id` attribute
  #   * a read/write attribute called `location` that will be of type `Point` to hold 
  #   the location information of where the photo was taken.
  #   * a write-only (for now) attribute called `contents` that will be used to import and access
  #   the raw data of the photo. This will have varying data types depending on 
  #   context.
  attr_accessor :id, :location, :place
  attr_writer :contents

  # Class method `mongo_client` that returns a MongoDB Client from Mongoid
  #   referencing the default database from the `config/mongoid.yml` file 
  #   (**Hint**: `Mongoid::Clients.default`)
  def self.mongo_client
  	db = Mongo::Client.new('mongodb://localhost:27017')
  end

  # `initialize` method used to initialize the instance attributes of `Photo` 
  # from the hash returned from queries like `mongo_client.database.fs.find`. 
  # This method must
  #   * initialize `@id` to the string form of `_id` and `@location` to the `Point` form of
  #     `metadata.location` if these exist. The document hash is likely coming from query 
  #     results coming from `mongo_client.database.fs.find`.
  #   * create a default instance if no hash is present
  #   
  def initialize(hash={})
  	@id = hash[:_id].to_s if !hash[:_id].nil?
  	if !hash[:metadata].nil?
  		@location = Point.new(hash[:metadata][:location]) if !hash[:metadata][:location].nil?
  		@place = hash[:metadata][:place]
  	end
  end

  # Instance method to return true if the 
  # instance has been created within GridFS. This method must:
  #     * take no arguments
  #     * return true if the `photo` instance has been stored to GridFS (**Hint**: `@id.nil?`)
  def persisted?
  	!@id.nil?
  end

  # STEP 1:
  # Instance method `save` to store a new instance into GridFS. 
  # This method must:
  #   * check whether the instance is already persisted and do nothing (for now) 
  #     if already persisted (**Hint**: use your new `persisted?` method to 
  #     determine if your instance has been persisted) 
  #   * use the `exifr` gem to extract geolocation information from the `jpeg` image. 
  #   * store the content type of `image/jpeg` in the `GridFS` `contentType` file property.
  #   * store the `GeoJSON Point` format of the image location in the `GridFS` `metadata` 
  #     file property and the object in class' `location` property.
  #   * store the data contents in `GridFS`
  #   * store the generated `_id` for the file in the `:id` property of the `Photo` model
  #     instance.
  # STEP 2:
  # Update the logic within the existing `save` instance method
  # to update the file properties (not the file data -- just the file
  # properties/metadata) when called on a persisted instance. Previously, the
  # method only handled a new `Photo` instance that was yet persisted. This
  # method must:
  # * accept no inputs
  # * if the instance is not yet persisted, perform the existing logic to add the file to GridFS
  # * if the instance is already persisted (Hint: `persisted?` helper method added earlier) 
  #   update the file info (Hint: `find(...).update_one(...)`)
  def save
    if !persisted?
      gps = EXIFR::JPEG.new(@contents).gps

      description = {}
      description[:content_type] = 'image/jpeg'
      description[:metadata] = {}
      
      @location = Point.new(:lng => gps.longitude, :lat => gps.latitude)
      description[:metadata][:location] = @location.to_hash
      description[:metadata][:place] = @place

      if @contents
        @contents.rewind
        grid_file = Mongo::Grid::File.new(@contents.read, description)
        id = self.class.mongo_client.database.fs.insert_one(grid_file)
        @id = id.to_s
      end
    else
      self.class.mongo_client.database.fs.find(:_id => BSON::ObjectId(@id))
        .update_one(:$set => {
          :metadata => {
            :location => @location.to_hash,
            :place => @place
          }
        })
    end
  end

  #class method to the `Photo` class called `all`. This method must:
  # * accept an optional set of arguments for skipping into and limiting the results of a search
  # * default the offset (**Hint**: `skip`) to 0 and the limit to unlimited
  # * return a collection of `Photo` instances representing each file returned from the database
  # (**Hint**: `...find.map {|doc| Photo.new(doc) }`)
  def self.all(skip = 0, limit = nil)
  	docs = mongo_client.database.fs.find({}).skip(skip)
  	docs = docs.limit(limit) if !limit.nil?
  	docs.map do |doc|
  		Photo.new(doc)
  	end
  end

  #class method  `find` that will return an instance of a `Photo`
  # based on the input `id`. This method must:
  #   * accept a single String parameter for the `id`
  #   * locate the file associated with the `id` by converting it back to a `BSON::ObjectId`
  #     and using in an `:_id` query.
  #   * set the values of `id` and `location` witin the model class based on the properties
  #     returned from the query.
  #   * return an instance of the `Photo` model class
  def self.find(id)
  	doc = mongo_client.database.fs.find(:_id => BSON::ObjectId(id)).first
  	if doc.nil?
  		return nil
  	else
  		return Photo.new(doc)
  	end
  end

  #getter for `contents` that will return the data contents of the file.
  # This method must:
  #     * accept no arguments
  #     * read the data contents from GridFS for the associated file
  #     * return the data bytes
  def contents
  	doc = self.class.mongo_client.database.fs.find_one(:_id => BSON::ObjectId(@id))
  	if doc
  	  buffer = ""
  	  doc.chunks.reduce([]) do |x, chunk|
  	    buffer << chunk.data.data
  	  end
  	  return buffer
  	end
  end

  # Instance method  `destroy` to the `Photo` class that will delete the file and
  # contents associated with the ID of the object instance. This method must:
  #   * accept no arguments
  #   * delete the file and its contents from GridFS
  def destroy
  	self.class.mongo_client.database.fs.find(:_id => BSON::ObjectId(@id)).delete_one
  end


  ####################################################################
  # Relationships
  ####################################################################

  # Helper instance method that will return the `_id` of the document
  # within the `places` collection. This `place` document must be within a 
  # specified distance threshold of where the photo was taken. 
  # This `Photo` method must:
  #   * accept a maximum distance in meters 
  #   * uses the `near` class method in the `Place` model and its location to locate
  #     places within a maximum distance of where the photo was taken.
  #   * limit the result to only the nearest matching place (**Hint**: `limit()`)
  #   * limit the result to only the `_id` of the matching place document 
  #     **Hint**: `projection()`)
  #   * returns zero or one `BSON::ObjectId`s for the nearby place found
  def find_nearest_place_id(max_dist)
  	place = Place.near(@location, max_dist).limit(1).projection(:_id => 1).first
  	if place.nil?
  		return nil
  	else
  		return place[:_id]
  	end
  end

  # Add `Photo` the functionality to support a relationship with `Place`. 
  # Add a new `place` attribute in the `Photo` class to be used to realize a `Many-to-One` 
  # relationship between `Photo` and `Place`. 
  # The `Photo` class must:
  #     * add support for a `place` instance attribute in the model class. 
  #       You will be implementing a custom setter/getter for this attribute
  #     * store this new property within the file metadata (`metadata.place`)
  #     * update the `initialize` method to cache the contents of `metadata.place` 
  #       in an instance attribute called `@place`
  #     * update the `save` method to include the `@place` and `@location` properties 
  #       under the parent `metadata` property in the file info.
  #     * add a custom getter for `place` that will find and return a `Place` 
  #       instance that represents the stored ID (**Hint**: `Place.find`)
  #     * add a custom setter that will update the `place` ID by accepting a 
  #      `BSON::ObjectId`, String, or `Place` instance. 
  #     In all three cases you will want to derive a a `BSON::ObjectId` from what 
  #     is passed in.

  #Place getter
  def place
    if !@place.nil?
    	Place.find(@place.to_s)
    end
  end

  #Place setter
  def place=(new_place)
    if new_place.is_a?(Place)
    	@place = BSON::ObjectId.from_string(new_place.id)
    elsif new_place.is_a?(String)
    	@place = BSON::ObjectId.from_string(new_place)
    else
    	@place = new_place
    end
  end

  # Class method called `find_photos_for_place` that accepts the `BSON::ObjectId`
  # of a `Place` and returns a collection view of photo documents that have the foreign key
  # reference. This method must:
  #   * accept the ID of a `place` in either `BSON::ObjectId` or `String` ID form 
  #     (Hint: `BSON::ObjectId.from_string(place_id.to_s`) 
  #   * find GridFS file documents with the `BSON::ObjectId` form of that ID in 
  #     the `metadata.place` property.
  #   * return the result view

  def self.find_photos_for_place(place_id)
    if place_id.is_a?(BSON::ObjectId)
      new_id = place_id
    elsif place_id.is_a?(String)
      new_id = BSON::ObjectId.from_string(place_id.to_s)
    end
  	mongo_client.database.fs.find(:'metadata.place' => new_id)
  end

end
