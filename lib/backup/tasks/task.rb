# frozen_string_literal: true

module Backup
  module Tasks
    class Task
      attr_reader :progress, :options

      # Identifier used as parameter in the CLI to skip from executing
      def self.id = raise NotImplementedError

      def initialize(progress:, options:)
        @progress = progress
        @options = options
      end

      # Key string that identifies the task
      def key = raise NotImplementedError

      # Name of the task used for logging.
      def human_name = raise NotImplementedError

      # Where the task should put its backup file/dir
      def destination_path = raise NotImplementedError

      # The target factory method
      def target = raise NotImplementedError

      # Path to remove after a successful backup, uses #destination_path when not specified
      def cleanup_path
        destination_path
      end

      # `true` if the destination might not exist on a successful backup
      def destination_optional = false

      # `true` if the task can be used
      def enabled = true

      def enabled? = enabled
    end
  end
end
