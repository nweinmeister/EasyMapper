module EasyMapper
  attr_accessor :target_map, :output, :after

  def self.extended(base)
    base.class_eval do
      self.target_map = nil
    end
  end

  def map(input_map)
    self.target_map = input_map
  end

  def after_normalize(&block)
    self.after = block
  end

  def normalize(input_hash)
    output = normalize_hash(self.target_map, input_hash)
    output = after.call(input_hash, output) if after
    output
  end

  def normalize_hash(target_map, input, buried_keys = [], output = {})
    target_map.keys.each do |key|
      if key.include?('*')
        keys = key.split('*')
        handle_array(input[keys[1]], target_map[key], keys[0], output)
      else
        buried_keys.push(key)
        if target_map[key].is_a?(Hash)
          normalize_hash(target_map[key], input, buried_keys, output)
        else
          output.bury(buried_keys, find_input_value(input, target_map[key]))
        end
        buried_keys = []
      end
    end
    output
  end

  def handle_array(input, target_map, key, output)
    output[key] = input.map {|i| normalize_hash(target_map, i)}
  end

  def find_input_value(obj, key)
    return recurse_dig(key.split('#'), obj) if key.split('#').count > 1
    if obj.respond_to?(:key?) && obj.key?(key)
      obj[key]
    elsif obj.respond_to?(:each)
      r = nil
      obj.find{ |*a| r = find_input_value(a.last, key) }
      r
    end
  end

  def recurse_dig(keys, obj)
    if keys.count > 1
      key = keys.shift
      recurse_dig(keys, obj.dig(key))
    else
      return obj.dig(keys.shift)
    end
  end
end

class Hash
  def bury(keys, value)
    if keys.count < 1
      raise ArgumentError.new("2 or more arguments required")
    elsif keys.count == 1
      self[keys[0]] = value
    else
      key = keys.shift
      self[key] = {} unless self[key]
      self[key].bury(keys, value) unless keys.empty?
    end
    self
  end
end