# Configures the ceilometer database
# This class will install the required libraries depending on the driver
# specified in the connection_string parameter
#
# == Parameters
#  [*database_connection*]
#    the connection string. format: [driver]://[user]:[password]@[host]/[database]
#
class ceilometer::db (
  $database_connection = 'mysql://ceilometer:ceilometer@localhost/ceilometer'
) {

  include ceilometer::params

  Package<| title == 'ceilometer-common' |> -> Class['ceilometer::db']

  validate_re($database_connection,
    '(sqlite|mysql|postgresql|mongodb):\/\/(\S+:\S+@\S+\/\S+)?')

  case $database_connection {
    /^mysql:\/\//: {
      $backend_package = false
      include mysql::python
    }
    /^postgresql:\/\//: {
      $backend_package = 'python-psycopg2'
    }
    /^mongodb:\/\//: {
      $backend_package = $::ceilometer::params::pymongo_package_name
    }
    /^sqlite:\/\//: {
      $backend_package = $::ceilometer::params::sqlite_package_name
    }
    default: {
      fail('Unsupported backend configured')
    }
  }

  if $backend_package and !defined(Package[$backend_package]) {
    package {'ceilometer-backend-package':
      ensure => present,
      name   => $backend_package,
    }
  }

  ceilometer_config {
    'database/connection': value => $database_connection;
  }

  Ceilometer_config['database/connection'] ~> Exec['ceilometer-dbsync']

  exec { 'ceilometer-dbsync':
    command     => $::ceilometer::params::dbsync_command,
    path        => '/usr/bin',
    user        => $::ceilometer::params::username,
    refreshonly => true,
    logoutput   => on_failure,
    subscribe   => Ceilometer_config['database/connection']
  }

}
