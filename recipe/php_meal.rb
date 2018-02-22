# encoding: utf-8
require_relative 'php_common_recipes'
require_relative 'php5_recipe'
require_relative 'php7_recipe'

class PhpMeal
  attr_reader :name, :version

  def initialize(name, version, options)
    @name    = name
    @version = version
    @major_version = version.split('.').first
    @options = options
    @native_modules = []
    @extensions = []

    create_native_module_recipes
    create_extension_recipes

    (@native_modules + @extensions).each do |recipe|
      recipe.instance_variable_set('@php_path', php_recipe.path)

      if recipe.name == 'pdo_oci' || recipe.name == 'odbc' || recipe.name == 'pdo_odbc'
        recipe.instance_variable_set('@version', @version)
        recipe.instance_variable_set('@php_source', "#{php_recipe.send(:tmp_path)}/php-#{@version}")
        recipe.instance_variable_set('@files', [{url: recipe.url, md5: nil}])
      end
    end
  end

  def cook
    system <<-eof
      sudo zypper ref
      sudo zypper -n up
      sudo zypper -n in #{apt_packages}
      #{symlink_commands}
    eof

    if OraclePeclRecipe.oracle_sdk?
      Dir.chdir('/oracle') do
        system "ln -s libclntsh.so.* libclntsh.so"
      end
    end

    php_recipe.cook
    php_recipe.activate

    # native libraries
    @native_modules.each do |recipe|
      recipe.cook
    end

    # php extensions
    @extensions.each do |recipe|
      recipe.cook if should_cook?(recipe)
    end
  end

  def url
    php_recipe.url
  end

  def archive_files
    php_recipe.archive_files
  end

  def archive_path_name
    php_recipe.archive_path_name
  end

  def archive_filename
    php_recipe.archive_filename
  end

  def setup_tar
    php_recipe.setup_tar
    if OraclePeclRecipe.oracle_sdk?
      @extensions.detect{|r| r.name=='oci8'}.setup_tar
      @extensions.detect{|r| r.name=='pdo_oci'}.setup_tar
    end
    @extensions.detect{|r| r.name=='odbc'}&.setup_tar
    @extensions.detect{|r| r.name=='pdo_odbc'}&.setup_tar
  end

  private

  def create_native_module_recipes
    return unless @options[:php_extensions_file]
    php_extensions_hash = YAML.load_file(@options[:php_extensions_file])

    php_extensions_hash['native_modules'].each do |hash|
      klass = Kernel.const_get(hash['klass'])

      @native_modules << klass.new(
        hash['name'],
        hash['version'],
        md5: hash['md5'],
        sources_export_dir: @options[:sources_export_dir]
      )
    end
  end

  def create_extension_recipes
    return unless @options[:php_extensions_file]
    php_extensions_hash = YAML.load_file(@options[:php_extensions_file])

    php_extensions_hash['extensions'].each do |hash|
      klass = Kernel.const_get(hash['klass'])

      @extensions << klass.new(
        hash['name'],
        hash['version'],
        md5: hash['md5'],
        sources_export_dir: @options[:sources_export_dir]
      )
    end

    @extensions.each do |recipe|
      case recipe.name
      when 'amqp'
        recipe.instance_variable_set('@rabbitmq_path', @native_modules.detect{|r| r.name=='rabbitmq'}.work_path)
      when 'memcached'
        recipe.instance_variable_set('@libmemcached_path', @native_modules.detect{|r| r.name=='libmemcached'}.path)
      when 'lua'
        recipe.instance_variable_set('@lua_path', @native_modules.detect{|r| r.name=='lua'}.path)
      when 'phalcon'
        recipe.instance_variable_set('@php_version', "php#{@major_version}")
      when 'phpiredis'
        recipe.instance_variable_set('@hiredis_path', @native_modules.detect{|r| r.name=='hiredis'}.path)
      when 'odbc'
        recipe.instance_variable_set('@unixodbc_path', @native_modules.detect{|r| r.name=='unixodbc'}.path)
      when 'pdo_odbc'
        recipe.instance_variable_set('@unixodbc_path', @native_modules.detect{|r| r.name=='unixodbc'}.path)
      end
    end
  end

  def apt_packages
    if @major_version == '5'
      php5_apt_packages.join(" ")
    else
      php7_apt_packages.join(" ")
    end
  end

  def php5_apt_packages
    php_common_apt_packages + %w(automake freetds-devel)
  end

  def php7_apt_packages
    php_common_apt_packages + %w(libmemcached-dev)
  end

  def php_common_apt_packages
    %w(aspell-devel
      libc-client2007e_suse
      libexpat-devel
      gdbm-devel
      gmp-devel
      openldap2-devel
      libldb-devel
      libmcrypt-devel
      libpng12-devel
      libpng12-compat-devel
      libpspell15
      readline-devel
      sqlite3-devel
      libopenssl-devel
      libuv-devel
      libxml2-devel
      libzip-devel
      automake
      freetype2-devel
      libxslt-devel
      libGeoIP-devel
      ImageMagick-devel
      cyrus-sasl-devel
      imap-devel
      krb5-devel
      net-snmp-devel)
  end

  def symlink_commands
    if @major_version == '5'
      php5_symlinks.join("\n")
    else
      php7_symlinks.join("\n")
    end
  end

  def php5_symlinks
    ["sudo ln -fs /usr/lib64/libsybdb.so /usr/lib/libsybdb.so"]
  end

  def php7_symlinks
    []
  end

  def should_cook?(recipe)
    case recipe.name
    when 'phalcon'
       PhalconRecipe.build_phalcon?(version)
    when 'ioncube'
       IonCubeRecipe.build_ioncube?(version)
    when 'oci8', 'pdo_oci'
       OraclePeclRecipe.oracle_sdk?
    else
       true
    end
  end

  def files_hashs
    native_module_hashes = @native_modules.map do |recipe|
      recipe.send(:files_hashs)
    end.flatten

    extension_hashes = @extensions.map do |recipe|
      recipe.send(:files_hashs) if should_cook?(recipe)
    end.flatten.compact

    extension_hashes + native_module_hashes
  end

  def php_recipe
    php_recipe_options = {}

    hiredis_recipe = @native_modules.detect{|r| r.name=='hiredis'}
    libmemcached_recipe = @native_modules.detect{|r| r.name=='libmemcached'}
    ioncube_recipe = @extensions.detect{|r| r.name=='ioncube'}

    php_recipe_options[:hiredis_path] = hiredis_recipe.path unless hiredis_recipe.nil?
    php_recipe_options[:libmemcached_path] = libmemcached_recipe.path unless libmemcached_recipe.nil?
    php_recipe_options[:ioncube_path] = ioncube_recipe.path unless ioncube_recipe.nil?
    php_recipe_options[:sources_export_dir] = @options[:sources_export_dir]

    php_recipe_options.merge(DetermineChecksum.new(@options).to_h)

    if @major_version == '5'
      @php_recipe ||= Php5Recipe.new(@name, @version, php_recipe_options)
    else
      @php_recipe ||= Php7Recipe.new(@name, @version, php_recipe_options)
    end
  end
end
