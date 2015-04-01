$: << File.dirname(__FILE__)
require "eyes/version"
require "eyes/utils"
require "m3u8"
require "pry"

require File.join(File.dirname(__FILE__), 'aliyun', 'connection')
require File.join(File.dirname(__FILE__), 'eyes', 'watch_dog')
require File.join(File.dirname(__FILE__), 'eyes', 'segment_dog')

module Eyes
  # Your code goes here...
end
