# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Dataflow::Nodes::Embulk::S3ImportNode do
  let(:data_node) do
    Dataflow::Nodes::DataNode.create(
      name: 'data',
      db_name: 'dataflow_test',
      db_backend: :postgresql,
      schema: {
        id: { type: 'integer' },
        value: { type: 'string' }
      }
    )
  end
  let(:node) do
    Dataflow::Nodes::Embulk::S3ImportNode.create(
      name: 'test',
      data_node_id: data_node.id,
      s3_bucket: ENV['AWS_S3_BUCKET'],
      # Note: make sure the following data.csv.gz exists:
      s3_path_prefix: 'automatic_testing/gems/dataflow-embulk/data.csv.gz',
      s3_endpoint: "s3-#{ENV['AWS_S3_REGION']}.amazonaws.com",
      aws_access_key: ENV['AWS_ACCESS_KEY'],
      aws_secret_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
  end

  it 'recreates the table; imports from s3; adds the system _id column' do
    data_node.add(records: [{ id: 999, value: 'should not be here anymore' }])

    # condense all the tests that depend on processing
    # into a single one as the compute has a big overhead
    node.compute
    data_node = Dataflow.data_node('data')

    # it 'recreates the table'
    expect(data_node.count(where: { id: 999 })).to eq 0

    # it 'imports from s3'
    expect(node.count).to eq 10
    expect(node.find(where: { id: 5 })).to eq(id: 5, key: 'key5', value: 5)

    # it 'adds the system _id'
    expect(node.all(where: { id: 1 }, fields: [:_id])).to eq([{_id: 1}])

    # it 'is updated'
    expect(node.updated?).to eq true

    # until the next file is set
    node.s3_path_prefix = 'new_file.csv.gz'
    expect(node.updated?).to eq false
  end

  it 'is initially not updated' do
    expect(node.updated?).to eq false
  end

  it 'raises if there is no config' do
    expect { node.compute_impl }.to raise_error(Dataflow::Errors::InvalidConfigurationError)
  end

  def test_invalid_config(config_content)
    base_dir = "#{Dir.pwd}/tmp/dataflow-embulk"
    `mkdir -p #{base_dir}`

    filepath = "#{base_dir}/invalid.yml"
    File.write(filepath, config_content)
    node.instance_variable_set(:@config_file, filepath)

    expect { node.compute_impl }.to raise_error(RuntimeError)

    File.delete(filepath)
  end

  it 'raises if there is an unknown plugin' do
    config_content = <<END
in:
  type: unknown_plugin
out:
  type: unknown_plugin
END
    test_invalid_config(config_content)
  end

  it 'raises if there is an invalid config' do
    config_content = <<END
in:
  type: s3
END
    test_invalid_config(config_content)
  end
end
