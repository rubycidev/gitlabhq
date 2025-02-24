# frozen_string_literal: true

module ServicePing
  module ServicePingSettings
    extend self

    def enabled_and_consented?
      enabled? && !User.single_user&.requires_usage_stats_consent?
    end

    def enabled?
      ::Gitlab::CurrentSettings.usage_ping_enabled?
    end
  end
end

ServicePing::ServicePingSettings.extend_mod_with('ServicePing::ServicePingSettings')
