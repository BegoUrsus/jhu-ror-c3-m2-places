# Custom type called `AddressComponent`. This class must have:
#     * a read-only (String) attribute called `long_name`
#     * a read-only (String) attribute called `short_name`
#     * a read-only (array of Strings) attribute called `types`
#     * an `initialize` method that can set the attributes 
#       from a hash with keys `long_name`, `short_name`, and `types`.

#     Example hash:
#     {"long_name":"Bradford District",
#      "short_name":"Bradford District",
#      "types":["administrative_area_level_3", "political"]},

class AddressComponent
  attr_accessor :long_name, :short_name, :types

  def initialize(params={})
    @long_name = params[:long_name]
    @short_name = params[:short_name]
    @types = params[:types]
  end

end