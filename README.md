##Build State
This project uses continuous integration to help ensure that a quality product is delivered.
Travis CI monitors two branches (versions) of the code - Master (which is what gets released)
and Staging (which is what is currently being debugged ready for moving to master).

Master [![Build Status](https://secure.travis-ci.org/robertgauld/osm.png?branch=master)](http://travis-ci.org/robertgauld/osm)

Staging [![Build Status](https://secure.travis-ci.org/robertgauld/osm.png?branch=staging)](http://travis-ci.org/robertgauld/osm)


## OSM

Use the [Online Scout Manager](https://www.onlinescoutmanager.co.uk) API.


## Installation

**Requires Ruby 1.9.2 or later.**

Add to your Gemfile and run the `bundle` command to install it.

```ruby
gem 'osm'
```

Configure the gem during the initalization of the app (e.g. in config/initializers/osm.rb).
```ruby
ActionDispatch::Callbacks.to_prepare do
Osm::Api.configure(
  :api_id     => 'YOU WILL BE GIVEN THIS BY ED AT OSM',
  :api_token  => 'YOU WILL BE GIVEN THIS BY ED AT OSM',
  :api_name   => 'YOU WILL GIVE THIS TO ED AT OSM',
  :api_site   => :scout,
)
end
```


## Documentation & Versioning

Documentation can be found on [rubydoc.info](http://rubydoc.info/github/robertgauld/osm/master/frames)

We follow the [Semantic Versioning](http://semver.org/) concept,
however it should be noted that when the OSM API adds a feature it can be difficult to decide wether to bump the patch or minor version number up. A smaller change (such as adding score into the grouping object) will bump the patch whereas a larger change wil bump the minor version.
