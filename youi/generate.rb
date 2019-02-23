#!/usr/bin/env ruby
# © You i Labs Inc. 2000-2017. All rights reserved.

require 'fileutils'
require 'optparse'
require 'ostruct'
require 'json'

class GenerateOptions
    def self.parse(args)
        options = OpenStruct.new
        options.platform = nil
        options.build_directory = nil
        options.defines = {}
        options.url_scheme = nil

        options.engine_hint = nil
        options.use_jsbundle = false
        options.inline_jsbundle = false
        options.iterate_jsbundle = false
        options.dev_jsbundle = false
        options.minify_jsbundle = false
        options.jsbundle_directory = []
        options.jsbundle_file = []
        options.jsbundle_working_directory = nil

        platformList = ["Android", "Ios", "Linux", "Osx", "Ps4", "Roku2", "Roku4", "Tizen-Nacl", "Tvos", "Uwp", "Vs2017"]
        configurationList = ["Debug","Release"]

        unless File.exist?(File.join("#{__dir__}", "CMakeLists.txt"))
            puts "ERROR: The directory '#{__dir__}' does not contain a CMakeLists.txt file."
            exit 2
        end

        options_parser = OptionParser.new do |opts|
            opts.banner = "Usage: generate.rb [options]"

            opts.separator ""
            opts.separator "Arguments:"

            opts.on("-p", "--platform PLATFORM", String,
                "(REQUIRED) The name of the platform to generate the project for.",
                "  Supported platforms: #{platformList}") do |platform|
                unless platformList.any? { |s| s.casecmp(platform)==0 }
                    puts "ERROR: \"#{platform}\" is an invalid platform."
                    puts opts
                    exit 1
                end

                options.platform = platform
            end

            opts.on("-g", "--generator GENERATOR", String,
                "The name of the generator to use.",
                "  (If omitted, the default generator for the host machine will be used.)",
                "  (When 'AndroidStudio' is specified for the generator and 'Android' is set for the platform, ",
                "   an Android Studio project will be generated.)",
                "Supported generators by platform:",
                "Android:",
                "  - AndroidStudio (default)",
                "iOS/tvOS:",
                "  - Xcode (default)",
                "PS4:",
                "  - Visual Studio 11 [2012]",
                "  - Visual Studio 12 [2013]",
                "  - Visual Studio 14 [2015] (default)",
                "  Note: The PS4 SDK including the Visual Studio plugin for the selected generator must be installed.",
                "Tizen-NaCl:",
                "  - Eclipse CDT4 - Ninja (default if installed)",
                "  - Eclipse CDT4 - Unix Makefiles (default without ninja)",
                "Roku2/Roku4:",
                "  - Ninja (default if installed)",
                "  - Unix Makefiles (default without ninja)",
                "UWP:",
                "  - Visual Studio 15 Win64 [2017] (default)",
                "VS2017:",
                "  - Visual Studio 15 Win64 [2017] (default)",
                "Linux/OSX:",
                "  - Any generator supported by CMake. See cmake --help for details.",
                "  - OSX Default: Xcode",
                "  - Linux Default: Unix Makefiles") do |generator|
                options.generator = generator
            end

            opts.on("-b", "--build_directory DIRECTORY", String,
                "The directory in which the generated project files will be placed.") do |directory|
                options.build_directory = directory
            end

            opts.on("-d", "--define NAME=VALUE", String,
                "Add a defined variable and its value to pass along to CMake.") do |define_pair|

                key_value_pair = define_pair.split(/\s*=\s*/)
                if key_value_pair.length != 2
                    puts "Invalid format for -d: #{define_pair}"
                    puts opts
                    exit 1
                end

                options.defines[key_value_pair[0]] = key_value_pair[1]
            end

            opts.on("-c", "--config CONFIGURATION", String,
                "The configuration type #{configurationList} to send to the generator.",
                "  (This is only required for generators that do not support multiple configurations.)") do |config|
                if configurationList.any? { |s| s.casecmp(config)==0 }
                    options.defines["CMAKE_BUILD_TYPE"] = config
                else
                    puts "ERROR: \"#{config}\" is an invalid configuration type."
                    puts opts
                    exit 1
                end
            end

            opts.on("--url_scheme URL_SCHEME", String,
                "If included, the app will be able to be launched with deep links using this scheme.") do |url_scheme|
                options.url_scheme = url_scheme
            end

            opts.on("--youi_version ENGINE_HINT", String,
                "Can be set to a path (/path/to/5.0.0) or semantic version (5.0.0), and this project will generate against that version") do |engine_hint|
                options.engine_hint = engine_hint
            end

            opts.on("--dev",
                "If included, the js file will be bundled with the dev flag enabled. Requires either the '--local' or '--inline' option to be set.") do
                options.dev_jsbundle = true
            end

            opts.on("--minify",
                "If included, the js file will be bundled with the minify flag enabled. Requires either the '--local' or '--inline' option to be set.") do
                options.minify_jsbundle = true
            end

            opts.on("--local",
                "If included, JS bundles will be packaged locally, instead of fetched from a yarn server.") do
                options.use_jsbundle = true
            end

            opts.on("--inline",
                "If included, JS bundles will be compiled directly into source code, instead of fetched from a yarn server.") do
                options.use_jsbundle = true
                options.inline_jsbundle = true
            end

            opts.on("--iterate",
                "If included, Only JS bundles that need to be updated by changes to their source JS file will be re-bundled.",
                "  (If omitted, all JS bundles will be deleted before creating all required bundles.)",
                "  (A change to a JS file that is a dependency of the source JS file will not cause the file to be re-bundled.)") do
                options.iterate_jsbundle = true
            end

            opts.on("--file file", String,
                "The entry point for the application, for JS bundling.") do |file|
                options.jsbundle_file = file
            end

            opts.on("--directory directory", String,
                "If included, adds the JS files of the listed directory, and create a bundle for each one.") do |directory|
                options.jsbundle_directory = directory
            end


            opts.on_tail("-h", "--help", "Show usage and options list") do
                puts opts
                exit 1
            end
        end

        if args.count == 0
            puts options_parser
            exit 1
        end

        begin
            options_parser.parse!(args)
            mandatory = [:platform]
            missing = mandatory.select { |param| options[param].nil? }
            raise OptionParser::MissingArgument, missing.join(', ') unless missing.empty?

            if options.generator.nil?
                case options.platform
                when /android/i
                    options.generator = "AndroidStudio"
                when /osx/i
                    options.generator = "Xcode"
                when /ios|tvos/i
                    options.generator = "Xcode"
                when /UWP/i
                    options.generator = "Visual Studio 15 Win64"
                when /vs2017/i
                    options.generator = "Visual Studio 15 Win64"
                when /ps4/i
                    options.generator = "Visual Studio 14"
                when /linux/i
                    options.generator = "Unix Makefiles"
                when /Tizen-NaCl/i
                    ninja = system('ninja', [:out, :err] => File::NULL)
                    make = system('make', [:out, :err] => File::NULL)
                    if ninja != nil
                        options.generator = "Eclipse CDT4 - Ninja"
                    elsif make != nil
                        options.generator = "Eclipse CDT4 - Unix Makefiles"
                    else
                        puts "Could not find ninja or unix make. One of these generators must be installed to generate for Tizen-NaCl."
                        exit 1
                    end
                when /roku2|roku4/i
                    ninja = system('ninja', [:out, :err] => File::NULL)
                    make = system('make', [:out, :err] => File::NULL)
                    if ninja != nil
                        options.generator = "Ninja"
                    elsif make != nil
                        options.generator = "Unix Makefiles"
                    else
                        puts "Could not find ninja or unix make. One of these generators must be installed to generate for Roku2 or Roku4."
                        exit 1
                    end
                end
            end

            unless options.generator.match(/(Visual Studio)|Xcode|AndroidStudio/)
                unless options.defines.has_key?("CMAKE_BUILD_TYPE")
                    options.defines["CMAKE_BUILD_TYPE"] = "Debug"
                end
            end

            if (options.url_scheme)
                 options.defines["YI_BUNDLE_URL_SCHEME"] = "#{options.url_scheme}"
            end

            unless options.build_directory
                options.build_directory = File.expand_path(File.join(__dir__, "build", "#{options.platform.downcase}"))

                unless options.generator.match(/(Visual Studio)|Xcode/)
                    options.build_directory = File.join(options.build_directory, "#{options.defines["CMAKE_BUILD_TYPE"]}")
                end
            end

            if options.inline_jsbundle
                options.defines["YI_LOCAL_JS_INLINE"] = "ON"
            end

            if options.use_jsbundle
                options.jsbundle_working_directory = File.expand_path(File.join(__dir__, ".."))

                options.defines["YI_LOCAL_JS"] = "ON"
                options.defines["YI_BUNDLED_ASSETS_DEST"] = File.expand_path(File.join(options.build_directory, "Staging", "generated", "bundled_assets"))

                unless options.jsbundle_file.length > 0 || options.jsbundle_directory.length > 0
                    puts "ERROR: The --file or --directory argument is missing. Add one of these to specify the file/directory to include within the JS bundle."
                    abort
                end
            end

            return options
        rescue OptionParser::ParseError => e
            puts e
            puts ""
            puts options_parser
            exit 1
        end
    end

    def self.find_engine_dir_in_list(dirs)
        if dirs == nil || dirs.length == 0
            puts "ERROR: A non-empty list of directories must be passed to 'find_engine_dir_in_list'."
            abort
        end

        dirs.each { |d|
            config_filepath = File.absolute_path(File.join(d, "YouiEngineConfig.cmake"))
            if File.exist?(config_filepath)
                return d
            end

            # When in the engine repository, the YouiEngineConfig.cmake file doesn't exist at the root folder.
            # It's necessary to check for an alternative file.
            if File.exist?(File.absolute_path(File.join(d, "core", "CMakeLists.txt")))
                return d
            end
        }

        return nil
    end

    def self.sort_versions(vers)
        versions = []
        vers.each { |v|
            begin
                t = Gem::Version::new(v)
                versions.push(v)
            rescue
                # skip
            end
        }
        versions = versions.sort_by { |v| Gem::Version.new(v) }.reverse
    end

    def self.get_engine_dir(options)
        install_dir = File.join(ENV['HOME'], "youiengine")

        engine_dir = ""
        engine_dir = find_engine_dir_in_list([
            File.expand_path(__dir__),
            File.join(__dir__, ".."),
            File.join(__dir__, "..", ".."),
            File.join(__dir__, "..", "..", ".."),
            File.join(__dir__, "..", "..", "..", "..")
        ])
        if engine_dir != nil
            puts "WARNING: Found in engine directory. Will use this SDK, but please do out of SDK build!"
            return File.absolute_path(engine_dir)
        end

        if options.engine_hint != nil
            engine_dir = find_engine_dir_in_list([File.join(install_dir, options.engine_hint), options.engine_hint])
            if engine_dir != nil
                puts "Found engine directory #{engine_dir}"
                return File.absolute_path(engine_dir)
            else
                puts "ERROR: Passed youi_engine variable #{options.engine_hint}, but could not find valid You.i Engine install"
                puts "Ensure that you have that version installed in $HOME/youiengine/, or the provided path is correct."
                abort
            end
        end

        # For react projects, check for package.json one directory down to read engine version
        packageJson = File.expand_path(File.join(__dir__, "..", "package.json"))
        if File.exist?(File.absolute_path(packageJson))
            file = File.read(packageJson)
            pkgHash = JSON.parse(file)

            if pkgHash['dependencies'].key?('@youi/react-native-youi')
                depVersion = pkgHash['dependencies']['@youi/react-native-youi']

                engine_dir = find_engine_dir_in_list([File.join(install_dir, depVersion)])
                if engine_dir != nil
                    puts "Found engine directory #{engine_dir} based on version from package.json"
                    return File.absolute_path(engine_dir)
                else
                    puts "ERROR: Parsed @youi/react-native-youi version #{depVersion}, but could not find valid You.i Engine install"
                    puts "Ensure that you have that version installed in $HOME/youiengine/, or the provided path is correct. If you"
                    puts "know what you are doing you can force a different engine version by passing the --youi_engine argument."
                    puts "\nInstall the required version with \n\tyoui-tv install #{depVersion}\n"
                    abort
                end
            else
                puts "ERROR: Found package.json, but could not find @youi/react-native-youi dependency."
                puts "Ensure that you have upgraded your current application to the latest You.i Engine version. If you"
                puts "know what you are doing you can force a different engine version by passing the --youi_engine argument."
                puts "\nInstall the latest version with \n\tyoui-tv install\n"
                abort
            end
        end

        versions = Dir.entries(install_dir)
        versions = sort_versions(versions).map! {|v| File.join(install_dir, v)}
        engine_dir = find_engine_dir_in_list(versions)

        unless engine_dir != nil
            puts "ERROR: Could not locate an installation of You.i Engine. Please install via youi-tv"
            puts "command line app, and try again, or pass the path to the installed SDK with the"
            puts "generate.rb option --youi_version=[arg]"
            abort
        end
        return File.absolute_path(engine_dir)
    end

    def self.create_command(options)
        case options.platform
        when /Android/i
            return GenerateOptions.create_android_command(options)
        end

        return GenerateOptions.create_cmake_command(options)
    end

    def self.create_android_command(options)
        engine_dir = GenerateOptions.get_engine_dir(options)
        source_dir = "#{__dir__}"
        build_dir = File.join("#{source_dir}", "build", "#{options.platform.downcase}")
        if !options.build_directory.nil?
            build_dir = options.build_directory
        end
        build_dir = File.absolute_path(build_dir)
        command = "cmake"
        command << " -DYI_OUTPUT_DIR=\"#{build_dir}\""
        
        cmake_defines = ""
        options.defines.each do |key,value|
            cmake_defines << " -D#{key}=\"#{value}\""
        end
        command << "#{cmake_defines}"

        command << " -P \"#{File.join("#{engine_dir}", "cmake", "Modules", "YiGenerateAndroidStudioProject.cmake")}\""
        return command
    end

    def self.create_cmake_command(options)
        engine_dir = GenerateOptions.get_engine_dir(options)

        case options.platform
        when /ps4/i
            # PS4 uses the built-in version of CMake, so we need to reference that
            # version instead of the standard one installed on the host machine.
            command = "\"#{File.absolute_path(File.join(engine_dir, "tools", "build", "cmake", "bin", "cmake.exe"))}\""
        else
            command = "cmake "
        end

        command << "\"-B#{options.build_directory}\" \"-H#{__dir__}\""

        unless options.generator.nil?
            command << " -G \"#{options.generator}\""
        end

        unless options.defines.has_key?("CMAKE_TOOLCHAIN_FILE")
            toolchain_platform = ""
            platform_sub_values = options.platform.split("-")

            platform_sub_values.each do |value|
                toolchain_platform << value.capitalize
            end

            toolchain_subpath = File.join("cmake", "Toolchain", "Toolchain-" + toolchain_platform + ".cmake")

            toolchain_file = File.join(__dir__, toolchain_subpath)
            unless File.exist?(toolchain_file)
                toolchain_file = File.join(engine_dir, toolchain_subpath)
            end

            if File.exist?(toolchain_file)
                options.defines["CMAKE_TOOLCHAIN_FILE"] = toolchain_file
            end
        end

        cmake_defines = ""
        options.defines.each do |key,value|
            cmake_defines << " -D#{key}=\"#{value}\""
        end
        command << "#{cmake_defines}"

        return command
    end

    def self.generate_bundle(options)
        unless options.use_jsbundle || options.inline_jsbundle
            return
        end

        engine_dir = get_engine_dir(options)
        command = "ruby \"#{engine_dir}/tools/workflow/bundlejs.rb\" --working_directory \"#{options.jsbundle_working_directory}\" --platform \"#{options.platform.downcase}\""

        if options.jsbundle_file.length > 0
            command << " --input_files \"#{options.jsbundle_file}\""
        elsif options.jsbundle_directory.length > 0
            command << " --input_directories \"#{options.jsbundle_directory}\""
        end

        if options.defines.has_key?("CMAKE_BUILD_TYPE")
            if options.defines["CMAKE_BUILD_TYPE"].match(/Debug/i)
                command << " --dev"
            end
        end

        output_dir = File.expand_path(File.join(options.build_directory, "Staging", "generated", "jsbundles"))
        if options.inline_jsbundle
            command << " --minify"
            command << " --inline"
            output_dir = File.expand_path(File.join(output_dir, "InlineJSBundleGenerated"))
        end

        command << " --output \"#{output_dir}\""
        command << " --assets_dest \"#{options.defines["YI_BUNDLED_ASSETS_DEST"]}\""

        unless options.iterate_jsbundle
            if File.directory?(output_dir)
                FileUtils.rmtree(output_dir)
            end
        end

        unless system(command)
            abort
        end
    end
end

options = GenerateOptions.parse(ARGV)
GenerateOptions.generate_bundle(options)
command = GenerateOptions.create_command(options)

puts "#=============================================="
puts "CMake Generator command line:"
puts "  #{command}"
puts ""
puts "Platform: #{options.platform}"

if !options.generator.nil?
    puts "Generator: #{options.generator}"
end
puts ""

if options.defines.length > 0
    puts "Defines:"
    options.defines.each do |key,value|
        puts "  - #{key}: #{value}"
    end
end

puts "#=============================================="

command_result = system(command)
if command_result == false || command_result == nil
    if command_result == nil
        puts "Generation failed -- could not execute cmake command. Ensure that cmake is installed and available in your PATH."
    end
    abort()
end
