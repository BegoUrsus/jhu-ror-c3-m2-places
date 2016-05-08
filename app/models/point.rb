# Custom type called `Point`. This class must have:
#   * a read/write (Integer) attribute called `longitude`
#   * a read/write (Integer) attribute called `latitude`
#   * a `to_hash` instance method that will produce a `GeoJSON Point` hash
#   * an `initialize` method that can set the attributes from 
#     a hash with keys `lat` and `lng` or `GeoJSON Point` format.
#
#     Example hash:
#   GeoJSON Point format:   {"type":"Point", "coordinates":[ -1.8625303, 53.8256035]} 
#   Has with keys:      {"lat":53.8256035, "lng":-1.8625303} 

class Point
  attr_accessor :longitude, :latitude

  # Instance method that will produce `GeoJSON Point` hash 
  def to_hash
  	{
  		:type =>"Point",
  		:coordinates => [@longitude, @latitude]
  	}
  end

  # `initialize` method that can set the attributes from a hash with keys 
  # `lat` and `lng` or `GeoJSON Point` format
  def initialize(params)
    if !params[:coordinates].nil?
      @longitude = params[:coordinates][0]
      @latitude = params[:coordinates][1]
    else
      @longitude = params[:lng]
      @latitude = params[:lat]
    end
  end

end

