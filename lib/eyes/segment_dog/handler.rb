module Eyes
    module SegmentDog
        class Handler < EventMachine::FileWatch
            def initialize(opts={})
                @m3u8 = opts[:m3u8]
                @fnreg = opts[:fnreg]
                @callback = opts[:callback]
                super
            end

            # 通过m3u8库解析
            # ffmpeg生成时，只生成一个文件
            # 保证m3u8中只有一个ts记录
            # 让eyes可以获取片段元数据
            def file_modified
                Eyes::Utils.log "#{path} modified"
                segments = []

                meta{|segment_item|
                    shift_to_sized
                    if sized_segments_array.include?(segment_item.segment)
                        # 已经有过，则什么也不处理
                        Eyes::Utils.log "ERROR get same segment - #{segment_item.segment}"
                    else
                        # 否则，保存到列表中，做下次对比用
                        sized_segments_array << segment_item.segment
                        name = File.basename(segment_item.segment)
                        if(@fnreg =~ name)
                            ts = $1.to_i
                            segments << ts
                            path = file_path(ts)
                            upload(path, segment_item)
                        else
                            nil
                        end
                    end
                }

                if segments.size > 0
                    # 找到当前m3u8中最小的时间戳
                    # 所有小于该时间戳的文件，都可以删除
                    latest = segments.min

                    Dir[File.join(File.dirname(@m3u8), '*.ts')].map{|x|
                        name = File.basename(x)
                        if(@fnreg =~ name) and ($1.to_i < latest)
                            clean(x)
                        end
                    }
                else
                    Eyes::Utils.log "read segments empty"
                    Eyes::Utils.log `cat #{@m3u8}`
                end
            end

            def file_moved
                Eyes::Utils.log "#{path} moved"
            end

            def file_deleted
                Eyes::Utils.log "#{path} deleted"
            end

            def unbind
                Eyes::Utils.log "#{path} monitoring ceased"
            end

            private

            def meta
                File.open(@m3u8){|file|
                    playlist = M3u8::Playlist.read file
                    if playlist.items and (playlist.items.size > 0)
                        playlist.items.each { |e| yield e}
                    else
                        Eyes::Utils.log "No items found in m3u8 file - #{@m3u8}"
                        Eyes::Utils.log "content : #{`cat #{@m3u8}`}"
                    end
                }
            end

            def clean(path)
                Eyes::Utils.log "Delete expired file #{path}, and seq #{$1}"
                FileUtils.rm_f(path)
            end

            # 有内容更新的时候，要变更文件内容
            # 为了更方便的与外界第三方程序通信
            # 第三方程序可以使用inotify监听eyes.notify的变化，从而产生回调
            def notify_file(local_path, oss_path)
                File.open('eyes.notify', 'w+'){|f| f << "#{oss_path},#{local_path}" }
            end

            def upload(path, segment_item = nil)
                f = File.open(path, 'r')
                opath = oss_path(path)
                Eyes::Utils.log "put file to oss : #{opath}"
                begin
                    oss.put opath, f, :content_type => "video/MP2T"
                    # 回调事件
                    # 用于外界对上传文件完成后的处理
                    @callback and @callback.call(path, oss_full_path(opath), segment_item)
                    # 变更文件内容
                    notify_file(path, oss_full_path(opath))
                rescue RestClient::RequestTimeout => e
                    Eyes::Utils.log "upload file timeout : #{path}"
                rescue Errno::ETIMEDOUT => e
                    Eyes::Utils.log "upload file timeout : #{path}"
                rescue => e
                    Eyes::Utils.log "upload file failed : #{path}"
                    raise e
                end
            end

            def file_path(ts)
                File.join(File.dirname(@m3u8), "#{ts}.ts")
            end

            def oss_path(path)
                now = Time.now
                name = File.basename(path)
                "/#{now.year}/#{now.mon}/#{now.day}/#{now.hour}/#{name}"
            end

            def oss_full_path(path)
                oss.path_to_url(path)
            end

            def oss
                @oss ||= ::Aliyun::Connection.new(config)
            end

            def config
                @config ||= {
                    :aliyun_access_id => ENV["aliyun_access_id"],
                    :aliyun_access_key => ENV["aliyun_access_key"],
                    :aliyun_bucket => ENV["aliyun_bucket"],
                    :aliyun_area => ENV["aliyun_area"]
                }
            end

            # 发现会有重复的segments触发文件系统
            # 但新文件却还没有生成
            # 所以需要近期有部分segments保存下来做对比
            def sized_segments_array
                @_sized_segments_array ||= []
            end

            # 只保留100个最近的segment
            def shift_to_sized
                while sized_segments_array.size > 100
                    sized_segments_array.shift
                end
            end
        end
    end
end