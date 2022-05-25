require 'optparse'

class Main
  # global options
  @@options = {
    :team => nil,
    :name => nil,
    :year => nil,
    :connect => false
  }

  def parse_options
    OptionParser.new do |opts|
      # team number
      opts.on("-t", "--team=TEAM", Integer, "Team number to connect to")
    
      # network name
      opts.on("-n", "--name=NAME", String, "Network name excluding team number")
    
      # year for wpilib jdk
      opts.on("-y", "--year=YEAR", Integer, "WPILib version to use JDK from")

      # only connect to robot
      opts.on("-c", "--connect", "Only connect and not deploy")
    end.parse!(into: @@options)
  end

  def run
    # run command line options parser
    parse_options

    # output of netsh
    networks = %x(netsh wlan show networks).lines.filter do |line|
      # check if line is a network ssid
      line.start_with?(/SSID [\d]+/)
    end.collect do |line|
      # remove start from string
      line.strip.gsub(/SSID [\d]+ : /, "")
    end

    # netsh exit code
    error = %x(echo %ERRORLEVEL%).strip.downcase == "false"

    # exit if netsh fails
    if error
      puts "Netsh failed with a non-zero exit code."
      exit(1)
    end

    # team and name are set by options if present otherwise default regex
    team = (@@options[:team].nil?) ? '^[\d]{3,4}' : "^(#{@@options[:team].to_s[0..3]})"
    name = (@@options[:name].nil?) ? '[\w]*$' : "_(#{@@options[:name].strip})$"
    frc_regexp = Regexp.new(team + name)

    # check which networks match the frc radio name regex
    networks.filter! do |network|
      frc_regexp.match?(network) 
    end

    # exit if no robot network to connect to
    if networks.empty?
      puts "No robot network found to connect to."
      exit(2)
    end

    # index of desired network
    index = 0

    # prompt user if more than one option is present after regex
    if networks.length > 1
      puts "Multiple networks found:\n"
      
      # print out each index and option
      networks.each_index do |index|
        puts "[#{index+1}] #{networks[index]}"
      end

      # get user input
      print "\nEnter index of network to connect to: "
      index = gets.chomp.to_i - 1

      # exit if incorrect index
      if index < 0 || index > networks.length - 1
        puts "Index out of bounds."
        exit(1)
      end
    end

    # connect to the desired network
    %x(netsh wlan connect ssid=#{networks[index]} name=#{networks[index]})
    error = %x(echo %ERRORLEVEL%).strip.downcase == "false"

    if !error
      puts "Successfully connected to robot network."

      # exit if connect-only mode is set
      if @@options[:connect]
        exit(0)
      end
    else
      puts "Failed to connect to robot network."
      exit(1)
    end

    # year for jdk location
    year = (@@options[:year].nil?) ? Time.now.year.to_s : @@options[:year]
    dir = "C:\\Users\\Public\\wpilib\\#{year}\\jdk"

    # check if jdk exists
    if !Dir.exists?(dir)
      puts "Invalid year provided. JDK not found."
      exit(1)
    end

    # set gradle wrapper java home
    ENV['JAVA_HOME'] = dir
    
    # run gradle deploy
    begin
      deploy = %x(gradlew.bat deploy)
      error = %x(echo %ERRORLEVEL%).strip.downcase.to_i != 0 
    rescue Errno::ENOENT
      # rescue and exit if gradle wrapper isn't found
      puts "Gradle wrapper not found. Make sure this is a WPILib project directory."
      exit(1)
    end
   
    puts deploy
  end
end

