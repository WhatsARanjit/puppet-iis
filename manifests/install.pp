class iis::install {
  dism { 'IIS-WebServer':
    ensure => present,
    all    => true,
    notify => Service['w3svc'],
    before => Service['w3svc']
  }

  service { 'w3svc':
    ensure => 'running',
    enable => 'true',
  }
}