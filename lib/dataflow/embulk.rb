# frozen_string_literal: true
require 'dataflow-rb'
require 'dataflow/embulk/version'

module Dataflow
  module Nodes
    module Embulk
    end
  end
end


require 'dataflow/nodes/embulk/import_node.rb'
require 'dataflow/nodes/embulk/local_import_node.rb'
require 'dataflow/nodes/embulk/s3_import_node.rb'