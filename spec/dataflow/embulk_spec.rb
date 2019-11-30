# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Dataflow::Embulk do
  it 'has a version number' do
    expect(Dataflow::Embulk::VERSION).not_to be nil
  end

  it 'has embulk installed' do
    expect {
      Bundler.with_clean_env do
        res = `embulk --version`
        expect(res).to match(/^embulk 0.8.[0-9]+\n$/)
      end
    }.not_to raise_error
  end
end
