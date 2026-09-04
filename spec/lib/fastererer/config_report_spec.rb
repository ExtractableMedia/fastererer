# frozen_string_literal: true

require 'spec_helper'

describe Fastererer::ConfigReport do
  include FileHelper

  include_context 'isolated environment'

  let(:out) { StringIO.new }
  let(:config_name) { Fastererer::Config::FILE_NAME }

  describe '#render' do
    context 'with no project config file' do
      before { render }

      it 'says so in the header rather than naming a path' do
        expect(out.string).to include('Project config: none')
      end

      it 'attributes the new speedups mode to the defaults' do
        expect(out.string).to match(/New speedups:\s+warn \(default\)/)
      end

      it 'attributes every speedup to the defaults' do
        expect(out.string).to match(/gsub_vs_tr\s+enabled\s+default/)
      end

      it 'attributes every exclude path to the defaults' do
        expect(out.string).to match(%r{vendor/\*\*/\*\.rb\s+default})
      end
    end

    context 'with a speedup the project switches off' do
      before do
        create_file(config_name, ['speedups:', '  gsub_vs_tr: false'])
        render
      end

      it 'shows it as disabled and sourced from the project' do
        expect(out.string).to match(/gsub_vs_tr\s+disabled\s+project/)
      end

      it 'still attributes the untouched speedups to the defaults' do
        expect(out.string).to match(/sort_vs_sort_by\s+enabled\s+default/)
      end
    end

    context 'with a speedup held back' do
      before do
        create_file(config_name, ['speedups:', '  gsub_vs_tr: pending'])
        render
      end

      it 'distinguishes held back from disabled' do
        expect(out.string).to match(/gsub_vs_tr\s+held back\s+project/)
      end
    end

    context 'with a held-back speedup the project has enabled' do
      before do
        create_file(config_name, ['speedups:', '  gsub_vs_tr: pending', 'new_speedups: enable'])
        render
      end

      it 'shows it as enabled, because nothing is being held back' do
        expect(out.string).to match(/gsub_vs_tr\s+enabled\s+project/)
      end
    end

    context 'with a project exclude path and mode' do
      before do
        create_file(config_name, ['exclude_paths:', "  - 'db/schema.rb'", 'new_speedups: disable'])
        render
      end

      it 'attributes the added path to the project' do
        expect(out.string).to match(%r{db/schema\.rb\s+project})
      end

      it 'keeps the shipped paths attributed to the defaults' do
        expect(out.string).to match(%r{tmp/\*\*/\*\.rb\s+default})
      end

      it 'attributes the mode to the project' do
        expect(out.string).to match(/New speedups:\s+disable \(project\)/)
      end
    end
  end

  private

  def render
    described_class.new(config: Fastererer::Config.new, out:).render
  end
end
