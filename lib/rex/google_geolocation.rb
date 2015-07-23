#!/usr/bin/env ruby

require 'net/http'
require 'json'

module Rex
  # @example
  #   g = GoogleGeolocation.new
  #   g.add_wlan("00:11:22:33:44:55", "example", -80)
  #   g.fetch!
  #   puts g, g.google_maps_url
  class GoogleGeolocation

    GOOGLE_API_URI = "https://maps.googleapis.com/maps/api/browserlocation/json?browser=firefox&sensor=true&"

    attr_accessor :accuracy
    attr_accessor :latitude
    attr_accessor :longitude

    def initialize
      @uri = URI.parse(URI.encode(GOOGLE_API_URI))
      @wlan_list = []
    end

    # Ask Google's Maps API for the location of a given set of BSSIDs (MAC
    # addresses of access points), ESSIDs (AP names), and signal strengths.
    def fetch!
      @uri.query << @wlan_list.join("&wifi=")
      request = Net::HTTP::Get.new(@uri.request_uri)
      http = Net::HTTP::new(@uri.host,@uri.port)
      http.use_ssl = true
      response = http.request(request)

      if response && response.code == '200'
        results = JSON.parse(response.body)
        self.latitude = results["location"]["lat"]
        self.longitude = results["location"]["lng"]
        self.accuracy = results["accuracy"]
      else
        raise "Failure connecting to Google for location lookup."
      end
    end

    # Add an AP to the list to send to Google when {#fetch!} is called.
    #
    # Turns out Google's API doesn't really care about ESSID or signal strength
    # as long as you have BSSIDs. Presumably adding them will make it more
    # accurate? Who knows.
    #
    # @param mac [String] in the form "00:11:22:33:44:55"
    # @param ssid [String] ESSID associated with the mac
    # @param signal_strength [String] a thing like
    def add_wlan(mac, ssid = nil, signal_strength = nil)
      @wlan_list.push(URI.encode("mac:#{mac.upcase}|ssid:#{ssid}|ss=#{signal_strength.to_i}"))
    end

    def google_maps_url
      "https://maps.google.com/?q=#{latitude},#{longitude}"
    end

    def to_s
      "Google indicates the device is within #{accuracy} meters of #{latitude},#{longitude}."
    end

  end
end

if $0 == __FILE__
  if ARGV.empty?
    $stderr.puts("Usage: #{$0} <mac> [mac] ...")
    $stderr.puts("Ask Google for the location of the given set of BSSIDs")
    $stderr.puts
    $stderr.puts("Example: iwlist sc 2>/dev/null|awk '/Address/{print $5}'|xargs #{$0}")
    exit(1)
  end
  g = Rex::GoogleGeolocation.new
  ARGV.each do |mac|
    g.add_wlan(mac, nil, -83)
  end
  g.fetch!
  puts g, g.google_maps_url
end
