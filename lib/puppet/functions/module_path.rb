# This is an autogenerated function, ported from the original legacy version.
# It /should work/ as is, but will not have all the benefits of the modern
# function API. You should see the function docs to learn how to add function
# signatures for type safety and to document this function using puppet-strings.
#
# https://puppet.com/docs/puppet/latest/custom_functions_ruby.html
#
# ---- original file header ----

# ---- original file header ----
#
# @summary
#   Summarise what the function does here
#
Puppet::Functions.create_function(:'module_path') do
  # @param args
  #   The original array of arguments. Port this to individually managed params
  #   to get the full benefit of the modern function API.
  #
  # @return [Data type]
  #   Describe what the function returns here
  #
  dispatch :default_impl do
    # Call the method named 'default_impl' when this is matched
    # Port this to match individual params for better type safety
    repeated_param 'Any', :args
  end


  def default_impl(*args)
    
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
end
