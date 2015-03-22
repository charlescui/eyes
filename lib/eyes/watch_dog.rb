require "set"
require "eventmachine"

require File.join(File.dirname(__FILE__), 'watch_dog', 'handler')
require File.join(File.dirname(__FILE__), 'watch_dog', 'monitor')

module Eyes
    module WatchDog
        class NoProcessHandlerExecption < Exception; end
        class NoPidMethodExecption < Exception; end
    end
end