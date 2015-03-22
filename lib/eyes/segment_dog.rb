require "set"
require "eventmachine"

require File.join(File.dirname(__FILE__), 'segment_dog', 'handler')
require File.join(File.dirname(__FILE__), 'segment_dog', 'monitor')

module Eyes
    module SegmentDog
        class NoProcessHandlerExecption < Exception; end
        class NoPidMethodExecption < Exception; end
    end
end