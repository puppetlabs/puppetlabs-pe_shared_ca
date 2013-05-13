Puppet::Parser::Functions.newfunction(:module_path, :type => :rvalue) do |args|
  raise Puppet::Error, "module_path(): requires a single module_name argument" if args.length != 1

  module_name = args[0]
  ## Origin: https://github.com/jordansissel/puppet-examples/tree/master/where-art-thou
  ## License: MIT

  # Split modulepath by ":"
  lookupvar("settings::modulepath").split(":").collect do |path|
    # Fully resolve the path so things like '.' become full path names like
    # /path/to/modules
    expandedpath = File.expand_path(path)

    # Check if this file (this template file) is in the path being examined
    if File.directory? "#{expandedpath}/#{module_name}"
      # If it is, return the current module path with the module name
      "#{expandedpath}/#{module_name}"
    else
      # Otherwise return nil
      nil
    end
    # Then select the first non-nil entry
  end.compact.first
end
