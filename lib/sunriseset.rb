require 'date'

# Calculates the sun rise and sunset times, with civil, naval and astronomical
# twilight values.
# Not sure of the origin of the code.
# I have seen a fortran version http://www.srrb.noaa.gov/highlights/sunrise/program.txt
# a .pl www.mso.anu.edu.au/~brian/grbs/astrosubs.pl
# and .vb versions too.
# All had the same comments, so are of a common origin.
class SunRiseSet
  VERSION = '0.9.2'.freeze
  include Math

  # because I live here
  LATITUDE_DEFAULT = -(36.0 + 59.0 / 60.0 + 27.60 / 3600)
  LONGITUDE_DEFAULT = (174.0 + 29 / 60.0 + 13.20 / 3600)

  # In degrees from the Zenith. Represents the Time
  # when we turn car lights on and off
  CIVIL_TWILIGHT = 96
  # In degrees from the Zenith. Represents the Time
  # when we can see the first light (dawn)
  NAVAL_TWILIGHT = 102
  # In degrees from the Zenith. Represents the Time
  # when the sun is not interfering with viewing distant stars.
  ASTRO_TWILIGHT = 108
  # 0.833 is allowing for the bending in the atmosphere.
  SUN_RISE_SET = 90.833

  # @return [DateTime] Naval Twilight begins
  # (Sun is begining to lighten the sky)
  attr_reader :astro_twilight_start
  # @return [DateTime] Naval Twilight begins
  attr_reader :naval_twilight_start
  # @return [DateTime] Civil Twilight begins
  attr_reader :civil_twilight_start
  # @return [DateTime] Sun rise
  attr_reader :sunrise

  # @return [DateTime] Sun set
  attr_reader :sunset
  # @return [DateTime] End of Civil Twilight
  attr_reader :civil_twilight_end
  # @return [DateTime] end of naval twilight
  attr_reader :naval_twilight_end
  # @return [DateTime] end of astronomical twilight (sky is now fully dark)
  attr_reader :astro_twilight_end

  # @return [DateTime] Sun is at the midpoint for today
  # (varies throughout the year)
  attr_reader :sol_noon

  # @return [SunRiseSet] Constructor for any datetime and location
  # @param [DateTime, #jd, #offset] datetime
  # @param [Float] latitude
  # @param [Float] longitude
  def initialize(datetime,
                 latitude = LATITUDE_DEFAULT,
                 longitude = LONGITUDE_DEFAULT)
    @latitude = latitude
    @longitude = longitude
    @julian_date = DateTime.jd(datetime.jd.to_f)
    # Shorthand for later use, where we want this value as a float.
    @julian_day = @julian_date.jd.to_f
    # datetime.utc_offset/86400 #time zone offset +
    # daylight savings as a fraction of a day
    @zone = datetime.offset
    @t = calc_time_julian_cent(@julian_day)
    calc_sun
  end

  # @return [SunRiseSet] Constructor for date == today, at location specified
  # @param [Float] latitude
  # @param [Float] longitude
  def self.today(latitude = LATITUDE_DEFAULT, longitude = LONGITUDE_DEFAULT)
    new(DateTime.now, latitude, longitude)
  end

  # @return [SunRiseSet] Constructor for date == today, at location specified
  # @param [Float] latitude
  # @param [Float] longitude
  def self.now(latitude = LATITUDE_DEFAULT, longitude = LONGITUDE_DEFAULT)
    new(DateTime.now, latitude, longitude)
  end

  def time_format(t)
    if t.nil?
      'Not Found'
    else
      t.strftime('%H:%M:%S %d-%m')
    end
  end

  # @return [String] dumps key attributes as a multiline string
  def to_s
    "Astro Twilight #{time_format(@astro_twilight_start)}\n" \
    "Naval Twilight #{time_format(@naval_twilight_start)}\n" \
    "Civil Twilight #{time_format(@civil_twilight_start)}\n" \
    "Sun Rises #{time_format(@sunrise)}\n" \
    "Solar noon  #{time_format(@sol_noon)}\n" \
    "Sun Sets #{time_format(@sunset)}\n" \
    "End of Civil Twilight  #{time_format(@civil_twilight_end)}\n" \
    "Naval Twilight #{time_format(@naval_twilight_end)}\n" \
    "Astro Twilight #{time_format(@astro_twilight_end)}\n"
  end
end
# doc
class SunRiseSet
  # @return [String] the constant VERSION
  def version
    VERSION
  end

  private

  def calc_rise
    # Calculate sunrise for this date
    # if no sunrise is found, set flag nosunrise

    @sunrise = calc_sunrise_utc(@julian_day)
    @civil_twilight_start = calc_sunrise_utc(@julian_day, CIVIL_TWILIGHT)
    @naval_twilight_start = calc_sunrise_utc(@julian_day, NAVAL_TWILIGHT)
    @astro_twilight_start = calc_sunrise_utc(@julian_day, ASTRO_TWILIGHT)
  end

  def calc_set
    # Calculate sunset for this date
    # if no sunrise is found, set flag nosunset
    @sunset = calc_sunset_utc(@julian_day)
    @civil_twilight_end = calc_sunset_utc(@julian_day, CIVIL_TWILIGHT)
    @naval_twilight_end = calc_sunset_utc(@julian_day, NAVAL_TWILIGHT)
    @astro_twilight_end = calc_sunset_utc(@julian_day, ASTRO_TWILIGHT)
  end

  def condition_recent_sunrise(doy)
    # if Northern hemisphere and spring or summer, OR
    # if Southern hemisphere and fall or winter, use
    # previous sunrise and next sunset
    ((@latitude > 66.4) && (doy > 79) && (doy < 267)) ||
      ((@latitude < -66.4) && ((doy < 83) || (doy > 263)))
  end

  def condition_next_sunrise(doy)
    # if Northern hemisphere and fall or winter, OR
    # if Southern hemisphere and spring or summer, use
    # next sunrise and previous sunset
    ((@latitude > 66.4) && ((doy < 83) || (doy > 263))) ||
      ((@latitude < -66.4) && (doy > 79) && (doy < 267))
  end

  def sunrise_nil(doy)
    if condition_recent_sunrise(doy)
      newjd = find_recent_sunrise(@julian_day, @latitude, @longitude)
      @sunrise = calc_sunrise_utc(newjd) # + @zone
    elsif condition_next_sunrise(doy)
      newjd = find_next_sunrise(@julian_day, @latitude, @longitude)
      @sunrise = calc_sunrise_utc(newjd) # + @zone
    else
      raise 'Cannot Find Sunrise!'
    end
  end

  def condition_next_sunset(doy)
    # if Northern hemisphere and spring or summer, OR
    # if Southern hemisphere and fall or winter, use
    # previous sunrise and next sunset
    ((@latitude > 66.4) && (doy > 79) && (doy < 267)) ||
      ((@latitude < -66.4) && ((doy < 83) || (doy > 263)))
  end

  def condition_recent_sunset(doy)
    # if Northern hemisphere and fall or winter, OR
    # if Southern hemisphere and spring or summer, use
    # next sunrise and last sunset
    ((@latitude > 66.4) && ((doy < 83) || (doy > 263))) ||
      ((@latitude < -66.4) && (doy > 79) && (doy < 267))
  end

  def sunset_nil(doy)
    if condition_next_sunset(doy)
      newjd = find_next_sunset(@julian_day, @latitude, @longitude)
      @sunset = calc_sunset_utc(newjd) #+ @zone
    elsif condition_recent_sunset(doy)
      newjd = find_recent_sunset(@julian_day, @latitude, @longitude)
      @sunset = calc_sunset_utc(newjd) #+ @zone
    else
      raise 'Cannot Find Sunset!'
    end
  end

  # calculate time of sunrise and sunset for the entered date and location.
  # In the special cases near earth's poles,
  # the date of nearest sunrise and set are reported.
  # @return [nil] fills in class DateTime attributes
  # :sunrise, :civil_twilight_start,
  # :naval_twilight_start, :astro_twilight_start
  # :sunset, :civil_twilight_end,
  # :naval_twilight_end, :astro_twilight_end
  def calc_sun
    calc_rise
    calc_set

    # Calculate solar noon for this date
    @sol_noon = to_datetime(@julian_day, calc_solar_noon_utc(@t))

    # No sunrise or sunset found for today
    doy = @julian_date.yday
    sunrise_nil(doy) if @sunrise.nil?
    sunset_nil(doy) if @sunset.nil?
  end

  # @param [Float] radian
  # @return [Float] angle in degrees
  def rad_to_deg(angle_rad)
    (180.0 * angle_rad / PI)
  end

  # @param [Float] degrees
  # @return [Float] angle in radians
  def deg_to_rad(angle_deg)
    (PI * angle_deg / 180.0)
  end
end

# doc
class SunRiseSet
  # convert Julian Day to centuries since J2000.0.
  # @param [Float] julian_day Julian Day
  # @return [Float] T value corresponding to the Julian Day
  def calc_time_julian_cent(julian_day)
    (julian_day - 2_451_545.0) / 36_525.0
  end

  # convert centuries since J2000.0 to Julian Day.
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] the Julian Day corresponding to the t value
  def calc_jd_from_julian_cent(t)
    t * 36_525.0 + 2_451_545.0
  end

  # calculate the Geometric Mean Longitude of the Sun
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] the Geometric Mean Longitude of the Sun in degrees
  def calc_geom_mean_lon_sun(t)
    l0 = 280.46646 + t * (36_000.76983 + 0.0003032 * t)
    l0 -= 360.0 while l0 > 360.0
    l0 += 360.0 while l0 < 0.0
    l0; # in degrees
  end

  # Calculate the Geometric Mean Anomaly of the Sun
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] the Geometric Mean Anomaly of the Sun in degrees
  def calc_geom_mean_anomaly_sun(t)
    357.52911 + t * (35_999.05029 - 0.0001537 * t) # in degrees
  end

  # calculate the eccentricity of earth's orbit
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] the unitless eccentricity
  def calc_eccentricity_earth_orbit(t)
    0.016708634 - t * (0.000042037 + 0.0000001267 * t) # unitless
  end

  def eoc_final(sinm, sin2m, sin3m, t)
    sinm * (1.914602 - t * (0.004817 + 0.000014 * t)) +
      sin2m * (0.019993 - 0.000101 * t) +
      sin3m * 0.000289 # in degrees
  end

  # calculate the equation of center for the sun
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] in degrees
  def calc_sun_eq_of_center(t)
    mrad = deg_to_rad(calc_geom_mean_anomaly_sun(t))
    sinm = sin(mrad)
    sin2m = sin(mrad + mrad)
    sin3m = sin(mrad + mrad + mrad)
    eoc_final(sinm, sin2m, sin3m, t)
  end

  # calculate the true longitude of the sun
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] sun's true longitude in degrees
  def calc_sun_true_lon(t)
    calc_geom_mean_lon_sun(t) + calc_sun_eq_of_center(t) # in degrees
  end

  # calculate the true anamoly of the sun
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] sun's true anamoly in degrees
  def calc_sun_true_anomaly(t)
    calc_geom_mean_anomaly_sun(t) + calc_sun_eq_of_center(t) # in degrees
  end

  # calculate the distance to the sun in AU
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] sun radius vector in AUs
  def calc_sun_rad_vector(t)
    v = calc_sun_true_anomaly(t)
    e = calc_eccentricity_earth_orbit(t)
    (1.000001018 * (1.0 - e * e)) / (1.0 + e * Math.cos(deg_to_rad(v))) # in AUs
  end

  # calculate the apparent longitude of the sun
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] sun's apparent longitude in degrees
  def calc_sun_apparent_lon(t)
    o = calc_sun_true_lon(t)
    omega = 125.04 - 1934.136 * t
    o - 0.00569 - 0.00478 * Math.sin(deg_to_rad(omega)) # in degrees
  end

  # calculate the mean obliquity of the ecliptic
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] mean obliquity in degrees
  def calc_mean_obliquity_of_ecliptic(t)
    seconds = 21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))
    23.0 + (26.0 + (seconds / 60.0)) / 60.0 # in degrees
  end

  # calculate the corrected obliquity of the ecliptic
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] corrected obliquity in degrees
  def calc_obliquity_correction(t)
    e0 = calc_mean_obliquity_of_ecliptic(t)
    omega = 125.04 - 1934.136 * t
    e0 + 0.00256 * Math.cos(deg_to_rad(omega)) # in degrees
  end
end

# doc
class SunRiseSet
  # calculate the right ascension of the sun
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] sun's right ascension in degrees
  def calc_sun_rt_ascension(t)
    e = calc_obliquity_correction(t)
    lambda = calc_sun_apparent_lon(t)
    tananum = (Math.cos(deg_to_rad(e)) * Math.sin(deg_to_rad(lambda)))
    tanadenom = Math.cos(deg_to_rad(lambda))
    rad_to_deg(Math.atan2(tananum, tanadenom)) # in degrees
  end

  # calculate the declination of the sun
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] sun's declination in degrees
  def calc_sun_declination(t)
    e = calc_obliquity_correction(t)
    lambda = calc_sun_apparent_lon(t)
    sint = Math.sin(deg_to_rad(e)) * Math.sin(deg_to_rad(lambda))
    rad_to_deg(Math.asin(sint)) # in degrees
  end

  def eot_final(e, l0, m, y)
    sin2l0 = Math.sin(2.0 * deg_to_rad(l0))
    sinm   = Math.sin(deg_to_rad(m))
    cos2l0 = Math.cos(2.0 * deg_to_rad(l0))
    sin4l0 = Math.sin(4.0 * deg_to_rad(l0))
    sin2m  = Math.sin(2.0 * deg_to_rad(m))

    rad_to_deg(
      y * sin2l0 -
    2.0 * e * sinm +
    4.0 * e * y * sinm * cos2l0 -
    0.5 * y * y * sin4l0 -
    1.25 * e * e * sin2m
    ) * 4.0 # in minutes of time
  end

  # calculate the difference between true solar time and mean solar time
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] equation of time in minutes of time
  def calc_equation_of_time(t)
    epsilon = calc_obliquity_correction(t)
    l0 = calc_geom_mean_lon_sun(t)
    e = calc_eccentricity_earth_orbit(t)
    m = calc_geom_mean_anomaly_sun(t)
    y = Math.tan(deg_to_rad(epsilon) / 2.0)
    y *= y
    eot_final(e, l0, m, y)
  end

  # calculate the hour angle of the sun at sunrise for the latitude
  # @param [Float] solar_dec  declination angle of sun in degrees
  # @param [SUN_RISE_SET,CIVIL_TWILIGHT,NAVAL_TWILIGHT,ASTRO_TWILIGHT] angle
  # @return [Float] hour angle of sunrise in radians
  #  0.833 is an approximation of the reflaction caused by the atmosphere
  def calc_hour_angle_sunrise(solar_dec, angle = SUN_RISE_SET)
    lat_rad = deg_to_rad(@latitude)
    sd_rad  = deg_to_rad(solar_dec)
    # puts "lat_rad = #{rad_to_deg(lat_rad)}" +
    #      "sd_rad = #{rad_to_deg(sd_rad)}" +
    #      " angle = #{angle}"

    # ha_arg = Math.cos(deg_to_rad(angle + 0.833)) /
    #   (Math.cos(lat_rad)*Math.cos(sd_rad)) -
    #    Math.tan(lat_rad) * Math.tan(sd_rad)
    ha_arg = Math.cos(deg_to_rad(angle)) /
             (Math.cos(lat_rad) * Math.cos(sd_rad)) -
             Math.tan(lat_rad) * Math.tan(sd_rad)
    Math.acos(ha_arg) # in radians
  end

  # calculate the hour angle of the sun at sunset for the
  # @param [Float] solar_dec  declination angle of sun in degrees
  # @param [SUN_RISE_SET,CIVIL_TWILIGHT,NAVAL_TWILIGHT,ASTRO_TWILIGHT] angle
  # @return [Float]  hour angle of sunset in radians
  def calc_hour_angle_sunset(solar_dec, angle = SUN_RISE_SET)
    -calc_hour_angle_sunrise(solar_dec, angle) # in radians
  end
end

# doc
class SunRiseSet
  # calculate the Universal Coordinated Time (UTC) of sunrise
  #      for the given day at the given location on earth
  # @param [Float] julian_day
  # @param [SUN_RISE_SET,CIVIL_TWILIGHT,NAVAL_TWILIGHT,ASTRO_TWILIGHT] angle
  # @return [DateTime]  Date and Time of event
  def calc_sunrise_utc(julian_day, angle = SUN_RISE_SET)
    # *** Find the time of solar noon at the location, and use
    #     that declination. This is better than start of the
    #     Julian day

    noonmin = calc_solar_noon_utc(@t)
    t_noon = calc_time_julian_cent(julian_day + noonmin / 1440.0)

    # *** First pass to approximate sunrise (using solar noon)

    eq_time = calc_equation_of_time(t_noon)
    solar_dec = calc_sun_declination(t_noon)
    hour_angle = calc_hour_angle_sunrise(solar_dec, angle)
    delta = -@longitude - rad_to_deg(hour_angle)
    time_diff = 4 * delta; # in minutes of time
    time_utc = 720 + time_diff - eq_time; # in minutes

    # *** Second pass includes fractional jday in gamma calc

    new_t = calc_time_julian_cent(
      calc_jd_from_julian_cent(@t) + time_utc / 1440.0
    )
    eq_time = calc_equation_of_time(new_t)
    solar_dec = calc_sun_declination(new_t)
    hour_angle = calc_hour_angle_sunrise(solar_dec, angle)
    delta = -@longitude - rad_to_deg(hour_angle)
    time_diff = 4 * delta
    time_utc = 720 + time_diff - eq_time; # in minutes

    to_datetime(julian_day, time_utc)
    # rescue Math::DomainError => error
    # return nil # didn't find a Sunrise today. Will be raised by
  end

  # calculate the Universal Coordinated Time (UTC) of solar
  #    noon for the given day at the given location on earth
  # @param [Float] t  number of Julian centuries since J2000.0
  # @return [Float] time in minutes from zero Z
  def calc_solar_noon_utc(t)
    # First pass uses approximate solar noon to calculate eq_time
    t_noon = calc_time_julian_cent(calc_jd_from_julian_cent(t) -
    @longitude / 360.0)
    eq_time = calc_equation_of_time(t_noon)
    solar_noon_utc = 720 - (@longitude * 4) - eq_time; # min

    new_t =
      calc_time_julian_cent(calc_jd_from_julian_cent(t) -
      0.5 + solar_noon_utc / 1_440.0)

    eq_time = calc_equation_of_time(new_t)
    solar_noon_utc = 720 - (@longitude * 4) - eq_time; # min

    solar_noon_utc
  end

  # calculate the Universal Coordinated Time (UTC) of sunset
  # for the given day at the given location on earth
  # @param [Float] julian_day
  # @param [SUN_RISE_SET,CIVIL_TWILIGHT,NAVAL_TWILIGHT,ASTRO_TWILIGHT] angle
  # @return [DateTime]  Date and Time of event
  def calc_sunset_utc(julian_day, angle = SUN_RISE_SET)
    # *** Find the time of solar noon at the location, and use
    #     that declination. This is better than start of the
    #     Julian day

    noonmin = calc_solar_noon_utc(@t)
    t_noon = calc_time_julian_cent(julian_day + noonmin / 1440.0)

    # First calculates sunrise and approx length of day

    eq_time = calc_equation_of_time(t_noon)
    solar_dec = calc_sun_declination(t_noon)
    hour_angle = calc_hour_angle_sunset(solar_dec, angle)

    delta = -@longitude - rad_to_deg(hour_angle)
    time_diff = 4 * delta
    time_utc = 720 + time_diff - eq_time

    # first pass used to include fractional day in gamma calc

    new_t = calc_time_julian_cent(calc_jd_from_julian_cent(@t) +
    time_utc / 1440.0)
    eq_time = calc_equation_of_time(new_t)
    solar_dec = calc_sun_declination(new_t)
    hour_angle = calc_hour_angle_sunset(solar_dec, angle)

    delta = -@longitude - rad_to_deg(hour_angle)
    time_diff = 4 * delta
    time_utc = 720 + time_diff - eq_time; # in minutes

    to_datetime(julian_day, time_utc)
    # rescue Math::DomainError => error
    # return nil # no Sunset
  end

  # calculate the julian day of the most recent sunrise
  #    starting from the given day at the given location on earth
  # @param [Float] julianday
  # @return [Float]  julian day of the most recent sunrise
  def find_recent_sunrise(julianday)
    time = calc_sunrise_utc(julianday)
    until isNumber(time)
      julianday -= 1.0
      time = calc_sunrise_utc(julianday)
    end

    julianday
  end

  # calculate the julian day of the most recent sunset
  #    starting from the given day at the given location on earth
  # @param [Float] julianday
  # @return [Float]  julian day of the most recent sunset
  def find_recent_sunset(julianday)
    time = calc_sunset_utc(julianday)
    until isNumber(time)
      julianday -= 1.0
      time = calc_sunset_utc(julianday)
    end

    julianday
  end

  # calculate the julian day of the next sunrise
  #    starting from the given day at the given location on earth
  # @param [Float] julianday
  # @return [Float]  julian day of the next sunrise
  def find_next_sunrise(julianday)
    time = calc_sunrise_utc(julianday)
    until isNumber(time)
      julianday += 1.0
      time = calc_sunrise_utc(julianday)
    end

    julianday
  end

  # calculate the julian day of the next sunset
  #    starting from the given day at the given location on earth
  # @param [Float] julianday
  # @return [Float]  julian day of the next sunset
  def find_next_sunset(julianday)
    time = calc_sunset_utc(julianday)
    until isNumber(time)
      julianday += 1.0
      time = calc_sunset_utc(julianday)
    end

    julianday
  end

  # convert julian day and minutes to datetime
  # @param [Float] @julian_day
  # @param [Float] minutes
  # @return [DateTime]
  def to_datetime(_x, minutes)
    DateTime.jd(@julian_day) + (minutes / 1440.0)
  end
end

if __FILE__ == $PROGRAM_NAME
  dt = DateTime.now
  lat = 41.94
  lng = -88.75
  cs = SunRiseSet.new(dt, lat, lng)
  puts cs
end
