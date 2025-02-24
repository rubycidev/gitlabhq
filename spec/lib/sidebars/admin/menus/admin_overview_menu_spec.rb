# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::AdminOverviewMenu, feature_category: :navigation do
  it_behaves_like 'Admin menu',
    link: '/admin',
    title: s_('Admin|Overview'),
    icon: 'overview'

  it_behaves_like 'Admin menu with sub menus'

  it_behaves_like 'Admin menu with extra container html options',
    extra_container_html_options: { testid: 'admin-overview-submenu-content' }
end
