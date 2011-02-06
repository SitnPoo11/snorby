class Sensor < ActiveRecord::Base

  set_table_name "sensor"

  set_primary_key :sid

  has_many :events, :dependent => :destroy, :foreign_key => :sid

  has_many :ips, :dependent => :destroy, :foreign_key => [:sid]
  
  has_many :notes, :dependent => :destroy, :foreign_key => [:sid]

  def cache
    Cache.where(:sid => sid).all
  end
  
  def sensor_name
    return name unless name == 'Click To Change Me'
    hostname
  end
  
  def daily_cache
    DailyCache.where(:sid => sid).all
  end

  def last
    return Event.find(sid, last_cid) unless last_cid.blank?
    false
  end
  
  #
  #  
  # 
  def event_percentage
    begin
      total_event_count = Sensor.all.map(&:events_count).sum
      ((self.events_count.to_f / total_event_count.to_f) * 100).round
    rescue FloatDomainError
      0
    end
  end

end
