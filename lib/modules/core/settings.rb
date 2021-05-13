module Settings

    class ProgramSettings
  
      #
      # Method for Nokogiri so I don't have to continually type Nokogiri::HTML
      #
      def page(site)
        response = RestClient::Request.execute(:url => site, :method => :get, :verify_ssl => false) # Fix #26 https://github.com/Ekultek/whitewidow/issues/26
        response.force_encoding('iso-8859-1').encode('utf-8')  # Force the response into UTF-8
        Nokogiri::HTML(response)  # Pull the HTML from the UTF-8 encoded response
      end
  
      #
      # This is actually pretty smart, it's used to parse the HTML and pull from css selectors
      #
      def parse(site, tag, i)
        parsing = page(site)
        parsing.css(tag)[i].to_s
      end
  =begin
      #
      # Verify that python is installed on the computer
      #
      def extract_python_env_type
        if PYTHON_ENV_VAR
          return "python"
        elsif !(PYTHON_ENV_VAR)
          raise "You need python 2.7.x to run sqlmap, you have #{system("python --version")}".red
        else
          return "python27"
        end
      end
  =end
      #
      # sqlmap configuration, will prompt you if you want to save the commands
      #
      def sqlmap_config
        last_request_file = File.open(SQLMAP_LAST_REQUEST_FILE, "a+")
        command_file = File.open(SQLMAP_CONFIG_PATH, "a+")
        if command_file.read == "false"
          commands = FORMAT.prompt('Enter sqlmap commands, python sqlmap.py -m SQL_VULN.LOG')  # Temp fix for issue #46, I'm working on a permanent fix https://github.com/WhitewidowScanner/whitewidow/issues/46
          default = FORMAT.prompt('Save as default?[y/N]')
          if default.downcase.start_with?('y')
            command_file.truncate(0)
            command_file.puts("python #{SQLMAP_PATH} -m #{SQL_VULN_SITES_LOG} #{commands}")
            FORMAT.info('Commands saved, re-run --sqlmap for changes to replicate.')
            return true
            # FORMAT.info("Commands saved, you need to rerun --sqlmap in order for the changes to take effect")
          else
            last_request_file.puts("python #{SQLMAP_PATH} -m #{SQL_VULN_SITES_LOG} #{commands}")
            return false
          end
        else
          FORMAT.info("Running default sqlmap commands: #{File.read(SQLMAP_CONFIG_PATH)}")
          return File.read(command_file).chomp
        end
      end
  
      #
      # Specify the download link for the user
      #
      def ruby_download_link
        if RUBY_PLATFORM =~ /linux/
          " running sudo apt-get install ruby-full"
        elsif RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/
          " going to this link: https://dl.bintray.com/oneclick/rubyinstaller/rubyinstaller-2.3.3.exe"
        else
          " going to this link: https://www.ruby-lang.org/en/documentation/installation/#package-management-systems"
        end  
      end
  
      #
      # Create a unique random issue name
      #
      def random_issue_name
        o = [('a'..'z'), ('A'..'Z'), (1..9)].map { |i| i.to_a }.flatten
        string = (0...7).map { o[rand(o.length)] }.join
        return string
      end
  
      #
      # Create the issue
      #
      def create_issue_page(issue, error, steps, query, error_log=IO.read(ERROR_LOG_PATH))
        CREATE_ISSUE.issue_template(issue, error, steps, query, error_log)
      end
  
      #
      # Blacklist the search query
      #
      def black_list_query(query, file_size)
        if File.size("#{SITES_TO_CHECK_PATH}") == file_size
          FORMAT.warning("No sites found for search query: #{query}. Adding query to blacklist so it won't be run again.")  # Add the query to the blacklist
          File.open("#{QUERY_BLACKLIST_PATH}", "a+") { |blacked| blacked.puts(SEARCH_QUERY) }
          FORMAT.info("Query added to blacklist and will not be run again, exiting..")
          exit(1)
        end
      end
  
      #
      # Hide the banner if the banner flag is used
      #
      def hide_banner?
        Whitewidow::Misc.new.spider unless OPTIONS[:banner]
      end
  
      #
      # Show the legal and TOS if the legal flag is used
      #
      def show_legal?
        Legal::Legal.new.legal if OPTIONS[:legal]
      end
  
      #
      # Customize your search queries if the dork flag is use
      #
      def extract_query!
        OPTIONS[:dork] || DEFAULT_SEARCH_QUERY
      end
  
      #
      # Extract a random user agent if the user agent flag is used
      #
      def random_agent?
        if OPTIONS[:agent]
          USER_AGENTS['rand_agents'][rand(1..110)]
        else
          DEFAULT_USER_AGENT
        end
      end
  
      #
      # Decide whether to use random column names, or a specific one
      #
      def random_col_name?
        if OPTIONS[:cols]
          OPTIONS[:cols]
        else
          File.readlines("#{PATH}/lib/lists/common_columns.txt").sample
        end
      end
  
      #
      # Create the payloads
      #
      def create_payloads(payload_file, root_key="payloads")
        # Create the payloads to use while searching for SQL injection
        # vulnerable sites
        # @param [Object] payload_file: File that the templates are in
        # @param [Object] root_key: The root key for the payloads file
        # Example:
        # >>> ;SELECT IF((LCwooh3),BENCHMARK(7000000,MD5(LCwooh3)),158002)
        rand_nums = rand(1000000)
        low_level_rand_nums = rand(10)
        fixed_num = rand(13)
        rand_strings = SETTINGS.random_issue_name
        random_comment = ERROR_BASED_SQL_INJECTION_TEST.sample
  
        payloads = []
  
        replacements = {
            "'[rand_num]'" => rand_nums,
            "'[fix_num]'" => fixed_num,
            "'[str]'" => rand_strings,
            "'[del_start]'" => "'#{rand_strings}'",
            "'[del_stop]'" => "'#{rand_strings}'",
            "'[low_level_rand_num]'" => low_level_rand_nums,
            "'[comment]'" => random_comment
        }
  
        payload_file = YAML.load_file(payload_file)
  
        payload_file[root_key].keys.each { |payload_type|
          current_payloads = payload_file[root_key][payload_type]
          current_payloads.each { |payload|
            (payloads ||= []) << payload.gsub(Regexp.union(replacements.keys), replacements)
          }
        }
        return payloads
      end
  
      #
      # Test the search query before beginning the process
      #
      def test_query(query, agent=nil, proxy_to_use=nil)
        test_agent = Mechanize.new
        if proxy_to_use != nil
          agent.set_proxy(proxy_to_use.split(":").first, proxy_to_use.split(":").last)
        end
        test_agent.user_agent = agent
        google_page = test_agent.get("http://google.com")
        google_form = google_page.form("f")
        begin
          google_form.q = query
        rescue NoMethodError
          FORMAT.warning("Query: #{query} is bad, will try again with another query..")
          return false
        end
      end
  
      #
      # Update the program to the newest version
      #
      def update!
        data = `git pull origin master 2>&1`  # Disabled $stdout for the git command
        if data.to_s.include?('Already up-to date')
          FORMAT.info('Whitewidow is already up-to date with origin master')
        elsif $?.exitstatus > 0  # If git doesn't exit with a 0
          FORMAT.fatal("Git failed to pull from origin master, manually download. #{REPO_LINK}")
        else
          FORMAT.info("Successfully updated to #{VERSION_STRING}")
          question = FORMAT.prompt('Update sqlmap?[y/N]')
          if question.downcase.start_with?('y')
            Dir.chdir("#{PATH}/lib/modules/core/tools/thirdparty/sqlmap")  # Change to sqlmap
            system('python sqlmap.py --update')
            Dir.chdir("#{PATH}")  # Change back to whitewidow
          end
        end
      end
  
    end
  
  end
  