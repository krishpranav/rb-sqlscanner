module Platform

    class CheckOS

        def Platform.windows?
            (WINDOWS_PLATFORM_REGEX =~ RUBY_PLATFORM) != nil
        end

        def Platform.mac?
            (DARWIN_PLATFORM_REGEX =~ RUBY_PLATFORM) != nil
        end

        def Platform.unix?
            !OS.windows?
        end

        def Platform.linux?
            OS.unix? and not OS.mac?
        end

        def check_platform_beep
            if Platform.windows?
              print "\a"  # Windows beep command
            elsif Platform.mac?
              system('say "beep"')  # Mac beep command
            else
              system('echo -e "\a"') # Linux and Unix beep
            end
        end
    end
end

            
