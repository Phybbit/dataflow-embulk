# frozen_string_literal: true
require 'open3'
require 'securerandom'
require 'yaml'

module Dataflow::Nodes::Embulk
  class ImportNode < Dataflow::Nodes::ComputeNode
    ensure_dependencies exactly: 0
    ensure_data_node_exists

    field :template_config_file, type: String
    field :guess_config, type: Boolean, default: true

    def pre_compute(*)
      # make sure the tmp dir exists
      `mkdir -p #{tmp_dir}`

      unless data_node.use_double_buffering
        logger.log("Settings data_node '#{data_node.name}' use_double_buffering to TRUE")
        data_node.use_double_buffering = true
        data_node.save
      end

      # parse the config, replace with the appropriate aws keys/path
      @run_id = SecureRandom.hex(4)
      @config_file = generate_config_file
      fetch_and_save_schema
    end

    def compute_impl
      @finished = false

      # on one thread run embulk,
      # on the other monitor the log for progress
      Parallel.each(2.times, in_threads: 2) do |i|
        if i == 0
          run_embulk
        else
          loop do
            monitor_progress
            sleep(0.2)
            break if @finished_running_embulk
          end
        end
      end

      data_node.updated_at = Time.now
      data_node.save!
    end


    private

    def generate_config_file
      raise 'Please set a default config' unless @default_config
      @db_name = data_node.db_name
      @dataset_name = data_node.write_dataset_name

      config_template = File.read(template_config_file) if template_config_file && File.exist?(template_config_file)
      config_template ||= File.read(File.join(File.dirname(__FILE__), 'config', @default_config))
      config = ERB.new(config_template).result(binding)

      temporary_config_name = "#{@run_id}_import_guessed_config.yml"
      config_path = File.join(tmp_dir, temporary_config_name)
      File.write(config_path, config)
      logger.log("Generated an embulk configuration to #{config_path}.")

      config_path
    end

    def fetch_and_save_schema
      @file_content_length = 0

      Bundler.with_clean_env do
        logger.log('Guessing the file contents...')
        content_length_line = `embulk guess #{@config_file} -o #{@config_file} -l debug | grep -E "Content-Length:\s[0-9]+$"`
        @file_content_length = content_length_line.split[-1].to_i
        logger.log('Done.')
      end if guess_config

      # parse the guessed config and set it as the schema
      config = YAML.load(File.read(@config_file))
      columns = config['in']['parser']['columns']
      sch = columns.map { |x| [x['name'], { 'type' => map_type(x['type']) }] }.to_h

      data_node.schema = sch
      data_node.save
    end

    def map_type(embulk_type)
      case embulk_type
      when 'long'
        return 'integer'
      when 'timestamp'
        return 'datetime'
      end

      embulk_type # return as-is
    end

    def run_embulk
      Bundler.with_clean_env do
        logger.log("Importing through embulk. Log: #{output_log_path}")
        cmd = "embulk run #{@config_file} --log #{output_log_path}"

        Open3.popen3(cmd) do |_stdin, stdout, stderr, _wait_thr|
          out = stdout.read # blocking until the program finishes
          err = stderr.read # blocking until the program finishes
          if out =~ /^Error/
            logger.log('It seems Embulk has failed to run. Output:')
            log_embulk_output(err)
            raise "Embulk didn't run '#{@config_file}' properly. Please investigate."
          elsif err =~ /^Usage: embulk run <config.yml>/
            logger.log('It seems Embulk has received non-valid arguments. Output:')
            log_embulk_output(err)
            raise Dataflow::Errors::InvalidConfigurationError, "Embulk didn't run '#{@config_file}' properly. Please investigate."
          end
        end

        warnings = `grep WARN #{output_log_path}`

        if warnings != ""
          logger.log("[POSSIBLE ERROR] EMBULK WARNINGS DETECTED while importing to #{data_node.name}!")
          warnings.split("\n").each do |line|
            logger.log(line)
          end

          raise "Error inferring schema for #{data_node.name}. Please specify it explicitly."
        end


        logger.log('Embulk finished importing.')
      end

      File.delete(@config_file) if @config_file.present?
      File.delete(output_log_path) if File.exist?(output_log_path)
    ensure
      @finished_running_embulk = true
    end

    def log_embulk_output(output)
      (output || 'No output found.').split("\n").each do |line, idx|
        logger.log("#{idx}: #{line}")
      end
    end

    def monitor_progress
      return unless File.exist?(output_log_path)
      @file_content_length = [@file_content_length.to_i, 1].max
      processed_bytes_lines = `cat #{output_log_path} | grep -E "\\([0-9,]+\s" | sed -E 's/.*\\(([0-9,]+)\sbytes\\)/\\1/' | sed -E 's/,//g'`
      processed_bytes = processed_bytes_lines.split("\n").map(&:strip).map(&:to_i).reduce(:+).to_i

      # this is not correct because the file_content_length is compressed (gz)
      # and the processed bytes are after compression.
      # For now assume a factor of compression of 10.
      progress = 100.0 * processed_bytes / (@file_content_length * 10.0)

      # make sure to truncate at 99.9%
      progress = [99.9, progress].min
      on_computing_progressed(pct_complete: progress)
      send_heartbeat
    end

    def output_log_path
      File.join(tmp_dir, "#{@run_id}_import.log")
    end

    def tmp_dir
      File.join(Dir.pwd, 'tmp', 'dataflow-embulk')
    end
  end
end
