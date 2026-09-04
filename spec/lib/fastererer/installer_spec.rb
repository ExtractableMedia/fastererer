# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

describe Fastererer::Installer do
  include FileHelper

  include_context 'isolated environment'

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:installer) { described_class.new(out:, err:) }
  let(:config_name) { Fastererer::Config::FILE_NAME }

  describe '#call' do
    context 'when no config file exists' do
      it 'reports success' do
        expect(installer.call).to be(true)
      end

      it 'writes the stub into the working directory' do
        installer.call
        expect(File).to exist(config_name)
      end

      it 'writes a stub that parses as YAML' do
        installer.call
        expect(YAML.safe_load_file(config_name)).to eq('new_speedups' => 'enable')
      end

      it 'writes a stub that changes nothing but the new speedups mode' do
        installer.call
        expect(Fastererer::Config.new.file).to eq(defaults_with_new_speedups('enable'))
      end

      it 'names the written file on the output stream' do
        installer.call
        expect(out.string).to include(config_name)
      end
    end

    context 'when a config file already exists' do
      before { create_file(config_name, 'speedups:') }

      it 'reports failure' do
        expect(installer.call).to be(false)
      end

      it 'leaves the existing content untouched' do
        installer.call
        expect(File.read(config_name)).to eq("speedups:\n")
      end

      it 'explains the refusal on the error stream' do
        installer.call
        expect(err.string).to include('already exists')
      end
    end

    context 'when a config file exists and force is set' do
      let(:installer) { described_class.new(out:, err:, force: true) }

      before { create_file(config_name, 'speedups:') }

      it 'reports success' do
        expect(installer.call).to be(true)
      end

      it 'replaces the existing content with the stub' do
        installer.call
        expect(YAML.safe_load_file(config_name)).to eq('new_speedups' => 'enable')
      end
    end

    context 'when a directory is given' do
      it 'writes into that directory rather than the working one' do
        Dir.mkdir('elsewhere')
        described_class.new(dir: 'elsewhere', out:, err:).call
        expect(File).to exist(File.join('elsewhere', config_name))
      end
    end
  end

  private

  def defaults_with_new_speedups(mode)
    Fastererer::DefaultConfig.load.merge(Fastererer::Config::NEW_SPEEDUPS_KEY => mode)
  end
end
