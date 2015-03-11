Puppet::Type.newtype(:iis_application) do
  desc 'The iis_application type creates and manages IIS  applications'
  ensurable

  newparam(:name, :namevar => true) do
    desc 'This is the name of the application'
    validate do |value|
      fail("#{name} is not a valid application name") unless value =~ /^[a-zA-Z0-9\-\_\.'\s]+$/
    end
  end

  newproperty(:path) do
    desc 'Path to the application folder'
    validate do |value|
      fail("File paths must be fully qualified, not '#{value}'") unless value =~ /^.:\// or value =~ /^\/\/[^\/]+\/[^\/]+/
    end
  end

  newproperty(:site) do
    desc 'The site in which this virtual directory exists'
    validate do |value|
      fail('Site is read-only attribute.  To change site, remove and create a new virtual directory')
    end
  end

  newproperty(:app_pool) do
    desc 'Application pool for the site'
    validate do |value|
      fail("#{app_pool} is not a valid application pool name") unless value =~ /^[a-zA-Z0-9\-\_'\s]+$/
    end
    defaultto :DefaultAppPool
  end

end
