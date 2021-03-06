# frozen_string_literal: true

# Patch for copy plugin assets sources to private directory
module RedminePluginAssetPipeline
  module Infectors
    module Redmine
      # Monkey Patch for Redmine::Plugin
      # move assets from all plugins to separate directory
      module Plugin
        extend ActiveSupport::Concern

        included do
          alias_method :mirror_assets, :mirror_assets_to_private

          class << self
            cattr_accessor :private_directory_base

            self.private_directory_base =
              File.join(Rails.root, 'private', 'plugin_assets')
          end
        end

        def private_directory
          File.join(self.class.private_directory_base, id.to_s)
        end

        def mirror_assets_to_private
          source = assets_directory
          destination = private_directory

          unless File.exist?(self.class.private_directory_base)
            FileUtils.mkdir_p(self.class.private_directory_base)
          end

          FileUtils.rm_rf(destination) if File.exist?(destination)
          return unless File.directory?(source)

          if RedmineApp::Application.config.assets.compile
            FileUtils.ln_s(source, destination) if File.exist?(source)
          else
            source_files = Dir[source + '/**/*']
            source_dirs = source_files.select { |d| File.directory?(d) }
            source_files -= source_dirs
            unless source_files.empty?
              base_target_dir = File.join(destination, File.dirname(source_files.first).gsub(source, ''))
              begin
                FileUtils.mkdir_p(base_target_dir)
              rescue StandardError => e
                raise "Could not create directory #{base_target_dir}: " + e.message
              end
            end
            source_dirs.each do |dir|
              # strip down these paths so we have simple, relative paths we can
              # add to the destination
              target_dir = File.join(destination, dir.gsub(source, ''))
              begin
                FileUtils.mkdir_p(target_dir)
              rescue StandardError => e
                raise "Could not create directory #{target_dir}: " + e.message
              end
            end

            source_files.each do |file|
              begin
                target = File.join(destination, file.gsub(source, ''))
                unless File.exist?(target) && FileUtils.identical?(file, target)
                  FileUtils.cp(file, target)
                end
              rescue StandardError => e
                raise "Could not copy #{file} to #{target}: " + e.message
              end
            end
          end
        end
      end
    end
  end
end
