module ApiHowtoHelper
  # Turn a url for an arbitrary georss feed into a Google Map of that data
  def mapify(url, zoom = 13)
      "http://maps.google.com/maps?f=q&hl=en&layer=&ie=UTF8&z=#{zoom}&om=1&q=#{CGI.escape(url)}"
  end

  def htmlify(url)
    url.gsub(/(\?|&|&amp;)([a-z_]+)=/, '\1<strong>\2</strong>=').gsub('&', '&amp;')
  end

  def api_host
    "api.planningalerts.org.au"
  end

  def api_key
    current_user.api_key if current_user
  end

  def api_example_address_url(format, key, address = Rails.application.config.planningalerts_api_example_address,
    radius = Rails.application.config.planningalerts_api_example_size)
    applications_url(host: api_host, format: format, address: address, radius: radius, key: key)
  end

  def api_example_latlong_url(format, key, lat = Rails.application.config.planningalerts_api_example_lat, lng = Rails.application.config.planningalerts_api_example_lng,
    radius = Rails.application.config.planningalerts_api_example_size)
    applications_url(host: api_host, format: format, lat: lat, lng: lng, radius: radius, key: key)
  end

  def api_example_area_url(format, key, bottom_left_lat = Rails.application.config.planningalerts_api_example_bottom_left_lat,
    bottom_left_lng = Rails.application.config.planningalerts_api_example_bottom_left_lng,
    top_right_lat = Rails.application.config.planningalerts_api_example_top_right_lat,
    top_right_lng = Rails.application.config.planningalerts_api_example_top_right_lng)
    applications_url(host: api_host, format: format,
      bottom_left_lat: bottom_left_lat, bottom_left_lng: bottom_left_lng,
      top_right_lat: top_right_lat, top_right_lng: top_right_lng,
      key: key)
  end

  def api_example_authority_url(format, key, authority = Rails.application.config.planningalerts_api_example_authority)
    authority_applications_url(host: api_host, format: format, authority_id: authority,
      key: key)
  end

  def api_example_postcode_url(format, key, postcode = Rails.application.config.planningalerts_api_example_postcode, extra_params = {})
    applications_url({host: api_host, format: format, postcode: postcode, key: key}.merge(extra_params))
  end

  def api_example_suburb_and_state_url(format, key, suburb = Rails.application.config.planningalerts_api_example_suburb, state = Rails.application.config.planningalerts_api_example_state)
    applications_url(host: api_host, format: format, suburb: suburb, state: state,
      key: key)
  end

  def api_example_address_url_html(format, key)
    # Doing this hackery with 11's and 22's so that we don't escape "[" and "]"
    t = api_example_address_url(format, key || "33", "11", "22")
    t = t.sub("11", "[address]")
    t = t.sub("22", "[distance_in_metres]")
    t = t.sub("33", "[key]") if key.nil?
    htmlify(t)
  end

  def api_example_latlong_url_html(format, key)
    t = api_example_latlong_url(format, key || "44", "11", "22", "33")
    t = t.sub("11", "[latitude]")
    t = t.sub("22", "[longitude]")
    t = t.sub("33", "[distance_in_metres]")
    t = t.sub("44", "[key]") if key.nil?
    htmlify(t)
  end

  def api_example_area_url_html(format, key)
    t = api_example_area_url(format, key || "33", "11", "22", "11", "22")
    t = t.gsub("11", "[latitude]")
    t = t.gsub("22", "[longitude]")
    t = t.sub("33", "[key]") if key.nil?
    htmlify(t)
  end

  def api_example_authority_url_html(format, key)
    t = api_example_authority_url(format, key || "22", "11")
    t = t.sub("11", "[name]")
    t = t.sub("22", "[key]") if key.nil?
    htmlify(t)
  end

  def api_example_postcode_url_html(format, key)
    t = api_example_postcode_url(format, key || "22", "11")
    t = t.sub("11", "[postcode]")
    t = t.sub("22", "[key]") if key.nil?
    htmlify(t)
  end

  def api_example_suburb_and_state_url_html(format, key)
    t = api_example_suburb_and_state_url(format, key || "33", "11", "22")
    t = t.sub("11", "[suburb]")
    t = t.sub("22", "[state]")
    t = t.sub("33", "[key]") if key.nil?
    htmlify(t)
  end
end
