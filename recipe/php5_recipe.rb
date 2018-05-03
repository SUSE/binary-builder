# encoding: utf-8
require_relative 'php_common_recipes'

class Php5Recipe < BaseRecipe
  def configure_options
    [
      '--disable-static',
      '--enable-shared',
      '--enable-ftp=shared',
      '--enable-sockets=shared',
      '--enable-soap=shared',
      '--enable-fileinfo=shared',
      '--enable-bcmath',
      '--enable-calendar',
      '--enable-intl',
      '--with-kerberos',
      '--enable-zip=shared',
      '--with-bz2=shared',
      '--with-curl=shared',
      '--enable-dba=shared',
      '--with-cdb',
      '--with-gdbm',
      '--with-mcrypt=shared',
      '--with-mhash=shared',
      '--with-mysql=shared',
      '--with-mysqli=shared',
      '--enable-pdo=shared',
      '--with-pdo-sqlite=shared,/usr',
      '--with-pdo-mysql=shared,mysqlnd',
      '--with-mssql=shared',
      '--with-pdo-dblib=shared',
      '--with-gd=shared',
      '--with-jpeg-dir=/usr',
      '--with-freetype-dir=/usr',
      '--enable-gd-native-ttf',
      '--with-pdo-pgsql=shared',
      '--with-pgsql=shared',
      '--with-pspell=shared',
      '--with-gettext=shared',
      '--with-gmp=shared',
      '--with-imap=shared',
      '--with-imap-ssl=shared',
      '--with-ldap=shared',
      '--with-ldap-sasl',
      '--with-zlib=shared',
      '--with-xsl=shared',
      '--with-snmp=shared',
      '--enable-mbstring=shared',
      '--enable-mbregex',
      '--enable-exif=shared',
      '--with-openssl=shared',
      '--enable-fpm',
      '--enable-pcntl=shared',
      '--with-readline=shared',
      '--enable-sysvsem=shared',
      '--enable-sysvshm=shared',
      '--enable-sysvmsg=shared',
      '--enable-shmop=shared',
      '--with-libdir=lib64'
    ]
  end

  def url
    "https://php.net/distributions/php-#{version}.tar.gz"
  end

  def archive_files
    ["#{port_path}/*"]
  end

  def archive_path_name
    'php'
  end

  def configure
    return if configured?

    md5_file = File.join(tmp_path, 'configure.md5')
    digest   = Digest::MD5.hexdigest(computed_options.to_s)
    File.open(md5_file, 'w') { |f| f.write digest }

    # LIBS=-lz enables using zlib when configuring
    execute('configure', ['bash', '-c', "LIBS=-lz ./configure #{computed_options.join ' '}"])
  end

  def major_version
    @major_version ||= version.match(/^(\d+\.\d+)/)[1]
  end

  def zts_path
    Dir["#{path}/lib/php/extensions/no-debug-non-zts-*"].first
  end

  def setup_tar
  system <<-eof
      cp -a #{@hiredis_path}/lib/libhiredis.so* #{path}/lib/
      #cp #{@ioncube_path}/ioncube/ioncube_loader_lin_#{major_version}.so #{zts_path}/ioncube.so
      cp -a #{@libmemcached_path}/lib/libmemcached.so* #{path}/lib/
      cp -a #{@libmemcached_path}/lib/libmemcachedutil.so* #{path}/lib/
      cp -a /usr/lib64/libc-client.so* #{path}/lib/
      cp -a /usr/lib64/libmcrypt.so* #{path}/lib
      cp -a /usr/lib64/libaspell.so* #{path}/lib
      cp -a /usr/lib64/libpspell.so* #{path}/lib
      cp -a /usr/lib64//libgearman.so* #{path}/lib
      cp -a /usr/local/lib64/libcassandra.so* #{path}/lib
      cp -a /usr/lib64/libuv.so* #{path}/lib
      cp -a /usr/local/lib64/librabbitmq.so* #{path}/lib/
      cp -a /usr/lib64/libsybdb.so* #{path}/lib/
      cp -a /usr/lib/librdkafka.so* #{path}/lib
      cp -a /usr/lib64/libGeoIP.so* #{path}/lib/

      # Remove unused files
      rm "#{path}/etc/php-fpm.conf.default"
      rm -rf "#{path}/include"
      rm -rf "#{path}/php"
      rm -rf "#{path}/lib/php/build"
      rm "#{path}/bin/php-cgi"
      find "#{path}/lib/php/extensions" -name "*.a" -type f -delete
    eof
  end
end
