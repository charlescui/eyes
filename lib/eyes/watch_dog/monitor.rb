module Eyes
    module WatchDog
        class Monitor
            def initialize
                @pids = {}
                @watch_signature = {}
                register_child_sig
            end

            # 必须同时提供一个block作为进程挂掉之后的回调
            def monit(&blk)
                raise NoProcessHandlerExecption.new, "No handler set for #{pid}" if !block_given?
                # 启动一个进程来执行任务
                pid = Kernel.fork{
                    # 将子进程的输出到引导日志中
                    $stdout = File.open("watch_dog.out.#{$$}.log", 'w+')
                    $stdout.sync = true
                    $stderr = File.open("watch_dog.err.#{$$}.log", 'w+')
                    $stderr.sync = true
                    blk.call
                }
                # 当进程有故障退出发生时
                # 重新进入监控
                monit_blk = proc{
                    monit(&blk)
                }
                register_callback(pid, &monit_blk)
                add_new_monit(pid)
            end

            # 回收僵尸进程
            def register_child_sig
                Signal.trap(:CHLD){
                    @pids.keys.each { |pid|  
                        begin
                            Process.waitpid(pid)
                        rescue Errno::ECHILD => e
                            
                        end
                    }
                }
            end

            def register_callback(pid, &blk)
                Eyes::Utils.log "new #{pid} is moniting."
                wrap = proc{
                    Eyes::Utils.log "#{blk} will be call"
                    pid = blk.call
                    Eyes::Utils.log "#{blk} has be called"
                    pid
                }
                @pids[pid.to_i] = wrap
            end

            def register_signature(pid, sig)
                @watch_signature[pid.to_i] = sig
            end

            # 监控进程
            # 如果进程死掉，重启子进程
            def add_new_monit(pid)
                begin
                    if sig = @watch_signature[pid.to_i]
                        EventMachine::unwatch_pid(sig)
                    end
                    sig = EventMachine::watch_process(pid, Handler, @pids[pid.to_i])
                    register_signature(pid, sig)
                rescue EventMachine::Unsupported => e
                    # EventMachine's process monitoring API. On Mac OS X and *BSD this method is implemented using kqueue.
                    # Ubuntu暂不支持
                end
            end
        end
    end
end