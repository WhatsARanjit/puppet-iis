Puppet::Type.newtype(:iis_pool) do
  desc 'The iis_pool type creates and manages IIS application pools'
  ensurable

  newparam(:name, :namevar => true) do
    desc 'This is the name of the application pool'
    validate do |value|
      fail("#{name} is not a valid applcation pool name") unless value =~ /^[a-zA-Z0-9\-\_\.'\s]+$/
    end
  end

  newproperty(:enable_32_bit) do
    desc 'If 32-bit is enabled for the pool'
    newvalues(:false, :true)
    defaultto :false
  end

  newproperty(:runtime) do
    desc '.NET runtime version for the pool'
    munge do |value|
      value.to_f
      "v#{value}"
    end
  end

  newproperty(:pipeline) do
    desc 'The pipeline mode for the application pool'
    newvalues(:Integrated, :Classic, :integrated, :classic)
    munge do |value|
      value.capitalize
    end
  end

end
