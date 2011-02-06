class Cache < ActiveRecord::Base

  belongs_to :sensor, :foreign_key => [:sid]

  has_one :event, :foreign_key => [:sid, :cid]

  def self.gte(time)
    where("ran_at >= ?", time)
  end
  
  def self.lte(time)
    where("ran_at <= ?", time)
  end

  def self.last_month
    gte((Time.now - 2.months).beginning_of_month).lte((Time.now - 2.months).end_of_month)
  end

  def self.this_quarter
    gte(Time.now.beginning_of_quarter).lte(Time.now.end_of_quarter)
  end

  def self.this_month
    gte(Time.now.beginning_of_month).lte(Time.now.end_of_month)
  end

  def self.last_week
    gte((Time.now - 1.weeks).beginning_of_week).lte((Time.now - 1.weeks).end_of_week)
  end

  def self.this_week
    gte(Time.now.beginning_of_week).lte(Time.now.end_of_week)
  end

  def self.yesterday
    gte(Time.now.yesterday.beginning_of_day).lte(Time.now.yesterday.end_of_day)
  end

  def self.today
    gte(Time.now.beginning_of_day).lte(Time.now.end_of_day)
  end
  
  def self.cache_time
    if (time = get_last)
      return time.ran_at + 30.minute
    else
      Time.now - 30.minute
    end
  end

  def self.protocol_count(protocol, type=nil)
    count = []
    @cache = cache_for_type(self, :hour)

    case protocol.to_sym
    when :tcp
      @cache.each do |hour, data|
        count[hour] = data.map(&:tcp_count).sum
      end
    when :udp
      @cache.each do |hour, data|
        count[hour] = data.map(&:udp_count).sum
      end
    when :icmp
      @cache.each do |hour, data|
        count[hour] = data.map(&:icmp_count).sum
      end
    end

    range_for_type(:hour) do |i|
      next if count[i]
      count[i] = 0
    end

    count
  end

  def self.severity_count(severity, type=nil)
    count = []
    @cache = cache_for_type(self, :hour)

    case severity.to_sym
    when :high
      @cache.each do |hour, data|
        high_count = 0
        data.map(&:severity_metrics).each { |x| high_count += (x.kind_of?(Hash) ? (x.has_key?(1) ? x[1] : 0) : 0) }
        count[hour] = high_count
      end
    when :medium
      @cache.each do |hour, data|
        medium_count = 0
        data.map(&:severity_metrics).each { |x| medium_count += (x.kind_of?(Hash) ? (x.has_key?(2) ? x[2] : 0) : 0) }
        count[hour] = medium_count
      end
    when :low
      @cache.each do |hour, data|
        low_count = 0
        data.map(&:severity_metrics).each { |x| low_count += ( x.kind_of?(Hash) ? (x.has_key?(3) ? x[3] : 0) : 0) }
        count[hour] = low_count
      end
    end

    range_for_type(:hour) do |i|
      next if count[i]
      count[i] = 0
    end

    count
  end

  def self.get_last
    order('ran_at DESC').first
  end

  def self.sensor_metrics(type=nil)
    @metrics = []

    Sensor.limit(5).order('events_count DESC').each do |sensor|
      count = Array.new(24) { 0 }
      blah = self.where(:sid => sensor.sid).group_by { |x| x.ran_at.hour }

      blah.each do |hour, data|
        count[hour] = data.map(&:event_count).sum
      end

      @metrics << { :name => sensor.name, :data => count, :range => 24.times.to_a }
    end

    @metrics
  end

  def self.src_metrics(limit=20)
    @metrics = {}
    @top = []
    @cache = self.all.map(&:src_ips).compact
    count = 0

    @cache.each do |ip_hash|

      ip_hash.each do |ip, count|
        if @metrics.has_key?(ip)
          @metrics[ip] += count
        else
          @metrics.merge!({ip => count})
        end
      end
    end

    @metrics.sort{ |a,b| -1*(a[1]<=>b[1]) }.each do |data|
      break if count >= limit
      @top << data
      count += 1
    end
    
    @top
  end

  def self.dst_metrics(limit=20)
    @metrics = {}
    @top = []
    @cache = self.all.map(&:dst_ips).compact
    count = 0

    @cache.each do |ip_hash|

      ip_hash.each do |ip, count|
        if @metrics.has_key?(ip)
          @metrics[ip] += count
        else
          @metrics.merge!({ip => count})
        end
      end
    end

    @metrics.sort{ |a,b| -1*(a[1]<=>b[1]) }.each do |data|
      break if count >= limit
      @top << data
      count += 1
    end
    
    @top
  end

  def self.signature_metrics(limit=20)
    @metrics = {}
    @top = []
    @cache = self
    count = 0

    @cache.all.map(&:signature_metrics).each do |data|
      next unless data

      data.each do |id, value|
        if @metrics.has_key?(id)
          temp_count = @metrics[id]
          @metrics.merge!({id => temp_count + value})
        else
          @metrics.merge!({id => value})
        end
      end

    end

    @metrics.sort{ |a,b| -1*(a[1]<=>b[1]) }.each do |data|
      break if count >= limit
      @top << data
      count += 1
    end
    
    @top
  end

  def self.cache_for_type(collection, type=:week, sensor=false)
    case type.to_sym
    when :week
      return collection.all.group_by { |x| x.ran_at.day } unless sensor
      return collection.all(:sid => sensor.sid).group_by { |x| x.ran_at.day }
    when :month
      return collection.all.group_by { |x| x.ran_at.day } unless sensor
      return collection.all(:sid => sensor.sid).group_by { |x| x.ran_at.day }
    when :year
      return collection.all.group_by { |x| x.ran_at.month } unless sensor
      return collection.all(:sid => sensor.sid).group_by { |x| x.ran_at.month }
    when :hour
      return collection.all.group_by { |x| x.ran_at.hour } unless sensor
      return collection.all(:sid => sensor.sid).group_by { |x| x.ran_at.hour }
    else
      return collection.all.group_by { |x| x.ran_at.day } unless sensor
      return collection.all(:sid => sensor.sid).group_by { |x| x.ran_at.day }
    end
  end

  def self.range_for_type(type=:week, &block)

    case type.to_sym
    when :hour
      Time.now.beginning_of_day.hour.upto(Time.now.end_of_day.hour) do |i|
        block.call(i) if block
      end
    when :week
      Time.now.beginning_of_week.day.upto(Time.now.end_of_week.day) do |i|
        block.call(i) if block
      end
    when :month
      Time.now.beginning_of_month.day.upto(Time.now.end_of_month.day) do |i|
        block.call(i) if block
      end
    when :year
      start_time_method = :beginning_of_year
      end_time_method = :end_of_year
      Time.now.beginning_of_year.month.upto(Time.now.end_of_year.month) do |i|
        block.call(i) if block
      end
    else
      Time.now.beginning_of_week.day.upto(Time.now.end_of_week.day) do |i|
        block.call(i) if block
      end
    end

  end

end
