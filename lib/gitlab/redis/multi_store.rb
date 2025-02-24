# frozen_string_literal: true

module Gitlab
  module Redis
    class MultiStore
      include Gitlab::Utils::StrongMemoize

      class PipelinedDiffError < StandardError
        def initialize(non_default_store_result, default_store_result)
          @non_default_store_result = non_default_store_result
          @default_store_result = default_store_result
        end

        def message
          "Pipelined command executed on both stores successfully but results differ between them. " \
            "Result from the non-default store: #{@non_default_store_result.inspect}. " \
            "Result from the default store: #{@default_store_result.inspect}."
        end
      end

      class MethodMissingError < StandardError
        def initialize(cmd)
          @cmd = cmd
        end

        def message
          "Method missing #{@cmd}. Falling back to execute method on the redis default store in Rails.env.production."
        end
      end

      class NestedReadonlyPipelineError < StandardError
        def message
          'Nested use of with_readonly_pipeline is detected.'
        end
      end

      attr_reader :primary_pool, :secondary_pool, :instance_name, :primary_store, :secondary_store, :borrow_counter

      FAILED_TO_READ_ERROR_MESSAGE = 'Failed to read from the redis default_store.'
      FAILED_TO_WRITE_ERROR_MESSAGE = 'Failed to write to the redis non_default_store.'
      FAILED_TO_RUN_PIPELINE = 'Failed to execute pipeline on the redis non_default_store.'

      SKIP_LOG_METHOD_MISSING_FOR_COMMANDS = %i[info].freeze

      # _client and without_reconnect are Redis::Client methods which may be called through multistore
      REDIS_CLIENT_COMMANDS = %i[
        _client
        without_reconnect
      ].freeze

      PUBSUB_SUBSCRIBE_COMMANDS = %i[
        subscribe
        unsubscribe
      ].freeze

      READ_COMMANDS = %i[
        exists
        exists?
        get
        hexists
        hget
        hgetall
        hlen
        hmget
        hscan_each
        llen
        lrange
        mapped_hmget
        mget
        pfcount
        pttl
        scan
        scan_each
        scard
        sismember
        smembers
        sscan
        sscan_each
        strlen
        ttl
        type
        zcard
        zcount
        zrange
        zrangebyscore
        zrevrange
        zscan_each
        zscore
      ].freeze

      WRITE_COMMANDS = %i[
        decr
        del
        eval
        expire
        flushdb
        hdel
        hincrby
        hset
        incr
        incrby
        ltrim
        mapped_hmset
        pfadd
        pfmerge
        publish
        rpush
        sadd
        sadd?
        set
        setex
        setnx
        spop
        srem
        srem?
        unlink
        zadd
        zpopmin
        zrem
        zremrangebyrank
        zremrangebyscore

        memory
      ].freeze

      PIPELINED_COMMANDS = %i[
        pipelined
        multi
      ].freeze

      # To transition between two Redis store, `primary_pool` should be the connection pool for the target store,
      # and `secondary_pool` should be the connection pool for the current store.
      #
      # Transition is controlled with feature flags:
      # - At the default state, all read and write operations are executed in the secondary instance.
      # - Turning use_primary_and_secondary_stores_for_<instance_name> on: The store writes to both instances.
      #   The read commands are executed in the default store with no fallbacks.
      #   Other commands are executed in the the default instance (Secondary).
      # - Turning use_primary_store_as_default_for_<instance_name> on: The behavior is the same as above,
      #   but other commands are executed in the primary now.
      # - Turning use_primary_and_secondary_stores_for_<instance_name> off: commands are executed in the primary store.
      def initialize(primary_pool, secondary_pool, instance_name)
        @instance_name = instance_name
        @primary_pool = primary_pool
        @secondary_pool = secondary_pool

        @borrow_counter = "multi_store_borrowed_connection_#{instance_name}".to_sym

        validate_stores!
      end

      # Pipelines are sent to both instances by default since
      # they could execute both read and write commands.
      #
      # But for pipelines that only consists of read commands, this method
      # can be used to scope the pipeline and send it only to the default store.
      def with_readonly_pipeline
        raise NestedReadonlyPipelineError if readonly_pipeline?

        Thread.current[:readonly_pipeline] = true

        yield
      ensure
        Thread.current[:readonly_pipeline] = false
      end

      def readonly_pipeline?
        Thread.current[:readonly_pipeline].present?
      end

      # rubocop:disable GitlabSecurity/PublicSend
      (READ_COMMANDS + REDIS_CLIENT_COMMANDS + PUBSUB_SUBSCRIBE_COMMANDS).each do |name|
        define_method(name) do |*args, **kwargs, &block|
          if use_primary_and_secondary_stores?
            read_command(name, *args, **kwargs, &block)
          else
            default_store.send(name, *args, **kwargs, &block)
          end
        end
      end

      WRITE_COMMANDS.each do |name|
        define_method(name) do |*args, **kwargs, &block|
          if use_primary_and_secondary_stores?
            write_command(name, *args, **kwargs, &block)
          else
            default_store.send(name, *args, **kwargs, &block)
          end
        end
      end

      PIPELINED_COMMANDS.each do |name|
        define_method(name) do |*args, **kwargs, &block|
          if use_primary_and_secondary_stores? && !readonly_pipeline?
            pipelined_both(name, *args, **kwargs, &block)
          else
            send_command(default_store, name, *args, **kwargs, &block)
          end
        end
      end

      def method_missing(...)
        return @instance.send(...) if @instance

        log_method_missing(...)

        default_store.send(...)
      end
      # rubocop:enable GitlabSecurity/PublicSend

      def respond_to_missing?(command_name, include_private = false)
        true
      end

      def with_borrowed_connection
        primary_pool.with do |ps|
          secondary_pool.with do |ss|
            # nested borrows are allowed as ConnectionPool returns the existing connection
            # which the thread already checked out.
            Thread.current[borrow_counter] ||= 0
            Thread.current[borrow_counter] += 1

            # borrow from both pool as feature-flag could change during the period where connections are borrowed
            # this guarantees that we avoids a NilClass error
            @primary_store = ps
            @secondary_store = ss

            yield
          ensure
            # only set to nil after all nested borrows are yielded
            Thread.current[borrow_counter] -= 1
            if Thread.current[borrow_counter] == 0
              @primary_store = nil
              @secondary_store = nil
            end
          end
        end
      end

      # This is needed because of Redis::Rack::Connection is requiring Redis::Store
      # https://github.com/redis-store/redis-rack/blob/a833086ba494083b6a384a1a4e58b36573a9165d/lib/redis/rack/connection.rb#L15
      # Done similarly in https://github.com/lsegal/yard/blob/main/lib/yard/templates/template.rb#L122
      def is_a?(klass)
        return true if klass == default_store.class

        super(klass)
      end
      alias_method :kind_of?, :is_a?

      def to_s
        use_primary_and_secondary_stores? ? primary_store.to_s : default_store.to_s
      end

      def use_primary_and_secondary_stores?
        feature_flag = "use_primary_and_secondary_stores_for_#{instance_name.underscore}"

        feature_table_exists? &&
          Feature.enabled?(feature_flag, type: feature_flag_type(feature_flag)) && # rubocop:disable Cop/FeatureFlagUsage -- The flags are dynamic
          !same_redis_store?
      end

      def use_primary_store_as_default?
        feature_flag = "use_primary_store_as_default_for_#{instance_name.underscore}"

        feature_table_exists? &&
          Feature.enabled?(feature_flag, type: feature_flag_type(feature_flag)) && # rubocop:disable Cop/FeatureFlagUsage -- The flags are dynamic
          !same_redis_store?
      end

      def feature_flag_type(feature_flag)
        feature_definition = Feature::Definition.get(feature_flag)
        return if feature_definition

        :undefined
      end

      def increment_pipelined_command_error_count(command_name)
        @pipelined_command_error ||= Gitlab::Metrics.counter(:gitlab_redis_multi_store_pipelined_diff_error_total,
                                                             'Redis MultiStore pipelined command diff between stores')
        @pipelined_command_error.increment(command: command_name, instance_name: instance_name)
      end

      def increment_method_missing_count(command_name)
        @method_missing_counter ||= Gitlab::Metrics.counter(:gitlab_redis_multi_store_method_missing_total,
                                                            'Client side Redis MultiStore method missing')
        @method_missing_counter.increment(command: command_name, instance_name: instance_name)
      end

      def log_error(exception, command_name, extra = {})
        Gitlab::ErrorTracking.log_exception(
          exception,
          extra.merge(command_name: command_name, instance_name: instance_name))
      end

      def default_store
        use_primary_store_as_default? ? primary_store : secondary_store
      end

      def non_default_store
        use_primary_store_as_default? ? secondary_store : primary_store
      end

      def ping(message = nil)
        if use_primary_and_secondary_stores?
          # Both stores have to response success for the ping to be considered success.
          # We assume both stores cannot return different responses (only both "PONG" or both echo the message).
          # If either store is not reachable, an Error will be raised anyway thus taking any response works.
          [primary_store, secondary_store].map { |store| store.ping(message) }.first
        else
          default_store.ping(message)
        end
      end

      # connection_pool gem calls `#close` method:
      #
      # https://github.com/mperham/connection_pool/blob/v2.4.1/lib/connection_pool.rb#L63
      #
      # Let's define it explicitly instead of propagating it to method_missing
      def close
        return if primary_store.nil? || secondary_store.nil?

        if same_redis_store?
          # if same_redis_store?, `use_primary_store_as_default?` returns false
          # but we should avoid a feature-flag check in `.close` to avoid checking out
          # an ActiveRecord connection during clean up.
          secondary_store.close
        else
          [primary_store, secondary_store].map(&:close).first
        end
      end

      # blpop blocks until an element to be popped exist in the list or after a timeout.
      def blpop(*args)
        result = default_store.blpop(*args)
        if !!result && use_primary_and_secondary_stores?
          # special case to accommodate Gitlab::JobWaiter as blpop is only used in JobWaiter
          # 1s should be sufficient wait time to account for delays between 1st and 2nd lpush
          # https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2520#note_1630893702
          non_default_store.blpop(args.first, timeout: 1)
        end

        result
      end

      private

      # @return [Boolean]
      def feature_table_exists?
        # Use table_exists? (which uses ActiveRecord's schema cache) instead of Feature.feature_flags_available?
        # as the latter runs a ';' SQL query which causes a connection to be checked out.
        Feature::FlipperFeature.table_exists?
      rescue StandardError
        false
      end

      def log_method_missing(command_name, *_args)
        return if SKIP_LOG_METHOD_MISSING_FOR_COMMANDS.include?(command_name)

        raise MethodMissingError, command_name if Rails.env.test? || Rails.env.development?

        log_error(MethodMissingError.new(command_name), command_name)
        increment_method_missing_count(command_name)
      end

      def read_command(command_name, *args, **kwargs, &block)
        if @instance
          send_command(@instance, command_name, *args, **kwargs, &block)
        else
          read_from_default(command_name, *args, **kwargs, &block)
        end
      end

      def write_command(command_name, *args, **kwargs, &block)
        if @instance
          send_command(@instance, command_name, *args, **kwargs, &block)
        else
          write_both(command_name, *args, **kwargs, &block)
        end
      end

      def read_from_default(command_name, *args, **kwargs, &block)
        send_command(default_store, command_name, *args, **kwargs, &block)
      rescue StandardError => e
        log_error(e, command_name,
          multi_store_error_message: FAILED_TO_READ_ERROR_MESSAGE)
        raise
      end

      def write_both(command_name, *args, **kwargs, &block)
        result = send_command(default_store, command_name, *args, **kwargs, &block)

        # write to the non-default store only if write on default store is successful
        begin
          send_command(non_default_store, command_name, *args, **kwargs, &block)
        rescue StandardError => e
          log_error(e, command_name,
            multi_store_error_message: FAILED_TO_WRITE_ERROR_MESSAGE)
        end

        result
      end

      # Run the entire pipeline on both stores. We assume that `&block` is idempotent.
      def pipelined_both(command_name, *args, **kwargs, &block)
        result_default = send_command(default_store, command_name, *args, **kwargs, &block)

        begin
          result_non_default = send_command(non_default_store, command_name, *args, **kwargs, &block)
        rescue StandardError => e
          log_error(e, command_name, multi_store_error_message: FAILED_TO_RUN_PIPELINE)
        end

        # Pipelined commands return an array with all results. If they differ, log an error
        if result_non_default && result_non_default != result_default
          error = PipelinedDiffError.new(result_non_default, result_default)
          error.set_backtrace(Thread.current.backtrace[1..]) # Manually set backtrace, since the error is not `raise`d

          log_error(error, command_name)
          increment_pipelined_command_error_count(command_name)
        end

        result_default
      end

      def same_redis_store?
        strong_memoize(:same_redis_store) do
          # <Redis client v4.7.1 for unix:///path_to/redis/redis.socket/5>"
          # no borrowed connections due to endless recursion
          primary_pool.with(&:inspect) == secondary_pool.with(&:inspect) # rubocop:disable CodeReuse/ActiveRecord
        end
      end

      # rubocop:disable GitlabSecurity/PublicSend
      def send_command(redis_instance, command_name, *args, **kwargs, &block)
        # Run wrapped pipeline for each instance individually so that the fan-out is distinct.
        # If both primary and secondary are Redis Clusters, the slot-node distribution could
        # be different.
        #
        # We ignore args and kwargs since `pipelined` does not accept arguments
        # See https://github.com/redis/redis-rb/blob/v4.8.0/lib/redis.rb#L164
        if command_name.to_s == 'pipelined' && redis_instance._client.instance_of?(::Redis::Cluster)
          return Gitlab::Redis::CrossSlot::Pipeline.new(redis_instance).pipelined(&block)
        end

        if block
          # Make sure that block is wrapped and executed only on the redis instance that is executing the block
          redis_instance.send(command_name, *args, **kwargs) do |*params|
            with_instance(redis_instance, *params, &block)
          end
        else
          redis_instance.send(command_name, *args, **kwargs)
        end
      end
      # rubocop:enable GitlabSecurity/PublicSend

      def with_instance(instance, *params)
        @instance = instance

        yield(*params)
      ensure
        @instance = nil
      end

      def redis_store?(pool)
        pool.with { |c| c.instance_of?(Gitlab::Redis::MultiStore) || c.is_a?(::Redis) }
      end

      def validate_stores!
        raise ArgumentError, 'primary_store is required' if primary_pool.nil?
        raise ArgumentError, 'secondary_store is required' if secondary_pool.nil?
        raise ArgumentError, 'instance_name is required' unless instance_name
        raise ArgumentError, 'invalid primary_store' unless redis_store?(primary_pool)
        raise ArgumentError, 'invalid secondary_store' unless redis_store?(secondary_pool)
      end
    end
  end
end
