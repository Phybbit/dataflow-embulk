# frozen_string_literal: true
require 'open3'
require 'securerandom'
require 'yaml'

module Dataflow::Nodes::Embulk
  class LocalImportNode < ImportNode
    ensure_dependencies exactly: 0
    ensure_data_node_exists

    field :path_prefix,      type: String, required_for_computing: true
    field :last_path_prefix, type: String

    # Do not run if the path is already processed
    # (unless in force compute)
    def updated?
      last_path_prefix == path_prefix
    end

    def compute_impl
      super
      self.last_path_prefix = path_prefix
    end

    def generate_config_file
      @path_prefix = path_prefix
      @default_config = 'local_import.yml'

      super
    end
  end
end
