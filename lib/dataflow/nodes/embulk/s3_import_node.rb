# frozen_string_literal: true
require 'open3'
require 'securerandom'
require 'yaml'

module Dataflow::Nodes::Embulk
  class S3ImportNode < ImportNode
    ensure_dependencies exactly: 0
    ensure_data_node_exists

    field :s3_bucket,       type: String, required_for_computing: true
    field :s3_path_prefix,  type: String, required_for_computing: true
    field :s3_endpoint,     type: String, required_for_computing: true
    field :aws_access_key,  type: String, required_for_computing: true
    field :aws_secret_key,  type: String, required_for_computing: true
    field :last_s3_path_prefix, type: String

    # Do not run if the path is already processed
    # (unless in force compute)
    def updated?
      last_s3_path_prefix == s3_path_prefix
    end

    def compute_impl
      super
      self.last_s3_path_prefix = s3_path_prefix
    end

    private

    def generate_config_file
      @s3_bucket = s3_bucket
      @s3_path_prefix = s3_path_prefix
      @s3_endpoint = s3_endpoint
      @aws_access_key = aws_access_key
      @aws_secret_key = aws_secret_key
      @default_config = 's3_import.yml'

      super
    end
  end
end
