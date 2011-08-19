Capistrano::Configuration.instance(:must_exist).load do

  ############################################################################
  # These variables MUST be set in the client capfiles. If they are not set,
  # the deploy will fail with an error.
  ############################################################################
  _cset(:application) { abort "Please specify the name of your application, e.g. set :app_name, 'dna.co.nz'" }
  _cset(:deploy_to)   { abort "Please specify the deployment path, e.g. set :deploy_to, '/srv/www'" }
  _cset(:repository)  { abort "Please specify the repository URL. e.g. set :repository,  'http://svn.dna.co.nz/dna/internal/open/trunk'"  }
    
  ############################################################################
  # These variables may be set in the client capfile if their default values
  # are not sufficient.
  ############################################################################
  _cset(:apache_user)       { "apache" }
  _cset(:apache_group)      { "apache" }
  _cset(:keep_releases)     { 3 }
  _cset(:db_backup_dir)     { "#{deploy_to}/db-backup" }
  _cset(:local_db_user)     { 'root' }
  _cset(:local_db_password) { 'root' }
  _cset(:tmp_dir)           { '/tmp' }
  _cset(:deploy_via)        { :remote_cache }  
  default_run_options[:pty] = true  
  
  
  ############################################################################
  # These variables are set via user input
  ############################################################################
  _cset(:user) { Capistrano::CLI.ui.ask("Enter server username: ") }  
  _cset(:db_password) { Capistrano::CLI.ui.ask("Enter mysql password: ") }

  ############################################################################
  # These variables are set by inspecting silverstripe config
  ############################################################################  
  _cset(:db_name) { 
    configstring = capture "grep '^$database' #{current_path}/mysite/_config.php"
    if configstring =~ /['"](.*)['"]/
      $1
    else
      abort "Couldn't get :db_name from mysite/_config.php"
    end
  }

  ############################################################################
  # Utility Functions
  ############################################################################
  
  def remote_file_exists?(full_path)
    'true' ==  capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
  end
  
  ############################################################################
  # Recipes
  ############################################################################

  namespace :deploy do
    task :update do
      transaction do
        update_code
        remove_dev_files
        file_2_url
        symlink_assets
        symlink
      end
    end  
    task :symlink_assets do
      run "ln -nsf #{shared_path}/assets #{latest_release}/assets"
    end
    task :remove_dev_files do
      if remote_file_exists?("#{latest_release}/_ss_environment.php")
        run "rm #{latest_release}/_ss_environment.php"
      end
      if remote_file_exists?("#{latest_release}/capfile")
        run "rm #{latest_release}/capfile"
      end
    end
    task :file_2_url do
      run "echo \"\<\?php \\$_FILE_TO_URL_MAPPING\[\'#{latest_release}\'\] = \'http://#{application}/\'\;\" > #{deploy_to}/file2url.php"
    end
    task :fix_cache do
      set :cache_name, latest_release.gsub( "/", "-" )    
      run "#{sudo} cp #{tmp_dir}/silverstripe-cache#{cache_name}/manifest-cli-script #{tmp_dir}/silverstripe-cache#{cache_name}/manifest-main"      
      run "#{sudo} chown -R #{apache_user}:#{apache_group} #{tmp_dir}/silverstripe-cache#{cache_name}"
    end
    task :rebuild_hometemplate do
      run "cd #{latest_release}; sake / flush=all"
      run "curl http://#{application}/"
    end
    task :cleanup_cache do
      set :cache_name, deploy_to.gsub( "/", "-" )
      existing_cache_dirs = capture("ls #{tmp_dir} | grep silverstripe-cache#{cache_name}-releases")
      existing_cache_dirs.each { |dir| 
        run "echo #{dir}"
      }
    end
  end

  namespace :db do
    task :backup do
      run "mysqldump -u#{user} -p#{db_password} #{db_name} > #{db_backup_dir}/#{application}-#{release_name}.sql"
    end
    task :build do
      run "cd #{latest_release}; sake dev/build flush=1"
    end
    task :cleanup do
      count = fetch(:keep_releases, 5).to_i
      existing_backups = capture("ls #{db_backup_dir} | wc -l").to_i

      if count >= existing_backups
        logger.info "no old db backups to clean up"
      else
        logger.info "removing db backups"
        files = capture("ls -t1 #{db_backup_dir} | tail -n +#{keep_releases+1}")
        files.each { |file| 
          run "rm #{db_backup_dir}/#{file}"
        }
      end
    end
  end

  namespace :sync do
    task :default do
      assets
      database
    end
  
    desc "Mirrors the remote shared assets directory with local copy"
    task :assets do
        run_locally("rsync -avzP #{user}@#{application}:#{shared_path}/assets/ assets/")
    end
 
    desc "Copy production database dump to local machine, import into local development database"
    task :database do
      dump_file = capture("ls -1 #{db_backup_dir} | tail -n 1").rstrip  
      run_locally "scp #{user}@#{application}:#{db_backup_dir}/#{dump_file} ."
      run_locally "mysql -u#{local_db_user} -p#{local_db_password} #{db_name} < #{dump_file}"
    end
  end

  before("deploy:update", "db:backup")
  before("deploy:symlink", "db:build")
  after("db:build", "deploy:rebuild_hometemplate")
  after("db:build", "deploy:fix_cache")
  after("deploy:cleanup", "db:cleanup")
  before("sync:database", "db:backup")

end