class Stat
  
  def initialize
    @values = Array.new
  end
  
  def push( value )
    @values << value
  end
  
  def avg
    return nil if @values.size == 0
    @values.inject(0.0) { |sum, el| sum + el } / @values.size
  end
  
  def max
    @values.max
  end
  
  def min
    @values.min
  end
  
  def size
    @values.size
  end
  
end
