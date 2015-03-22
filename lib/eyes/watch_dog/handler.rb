module Eyes
    module WatchDog
        class Handler < EventMachine::ProcessWatch
            def initialize(blk)
                raise NoProcessHandlerExecption, "no callback in handler" if !blk
                @watch_dog_callback = blk
                super
            end

            def process_exited
                raise NoPidMethodExecption, "can't get pid in handler instance." if !pid
                Eyes::Utils.log "#{pid} has exited"
                @watch_dog_callback.call
            end
        end
    end
end