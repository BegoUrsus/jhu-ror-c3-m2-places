# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

require 'pp'
# 1. Clear GridFS of all files. You may use the model commands you
# implemented as a part of this assignment or lower-level GridFS or database
# commands to implement the removal of all files.
Photo.all.each { |photo| photo.destroy }

# 2. Clear the `places` collection of all documents. You may use the model
# commands you implemented as a part of this assignment or lower-level
# collection or database commands to implement the removal of all documents
# from the `places` collection.
Place.all.each { |place| place.destroy }

# 3. Make sure the `2dsphere` index has been created for the nested
# `geometry.geolocation` property within the `places` collection.
Place.create_indexes

# 4. Populate the `places` collection using the `db/places.json` file from
# the provided bootstrap files in `student-start`.
Place.load_all(File.open('./db/places.json'))

# 5. Populate GridFS with the images also located in the `db/` folder and supplied with the 
# bootstrap files in `student-start`.
#     Hint: The following snippet will loop thru the set of images. You must
#     ingest the contents of each of these files as a `Photo`.
#     ```ruby
#     > Dir.glob("./db/image*.jpg") { |f| p f}
#     "./db/image3.jpg"
#     ...
#     "./db/image2.jpg"
#     ```
Dir.glob("./db/image*.jpg") {|f| photo=Photo.new; photo.contents=File.open(f,'rb'); photo.save}

# 6. For each `photo` in GridFS, locate the nearest `place` within one (1) mile of each 
# `photo` and associated the `photo` with that `place`. (Hint: make sure to convert 
# miles to meters for the inputs to the search).
Photo.all.each {|photo| place_id=photo.find_nearest_place_id 1*1609.34; photo.place=place_id; photo.save}


# 7. As a self-test, verify that you have the following `place`s -- shown by their formatted address
# -- associated with a `photo` and can locate this association with a reference to the `place`.
pp Place.all.reject {|pl| pl.photos.empty?}.map {|pl| pl.formatted_address}.sort



