# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::GithubService, feature_category: :importers do
  let_it_be(:user) { create(:user) }
  let_it_be(:token) { 'complex-token' }
  let_it_be(:access_params) { { github_access_token: 'github-complex-token' } }

  let(:settings) { instance_double(Gitlab::GithubImport::Settings) }
  let(:user_namespace_path) { user.namespace_path }
  let(:optional_stages) { nil }
  let(:timeout_strategy) { "optimistic" }
  let(:params) do
    {
      repo_id: 123,
      new_name: 'new_repo',
      target_namespace: user_namespace_path,
      optional_stages: optional_stages,
      timeout_strategy: timeout_strategy
    }
  end

  let(:client) { Gitlab::GithubImport::Client.new(token) }
  let(:project_double) { instance_double(Project, persisted?: true) }

  subject(:github_importer) { described_class.new(client, user, params) }

  before do
    allow(Gitlab::GithubImport::Settings).to receive(:new).with(project_double).and_return(settings)
    allow(settings)
      .to receive(:write)
      .with(
        extended_events: true,
        optional_stages: optional_stages,
        timeout_strategy: timeout_strategy,
        prioritize_collaborators: true
      )
  end

  context 'do not raise an exception on input error' do
    let(:exception) { Octokit::ClientError.new(status: 404, body: 'Not Found') }

    before do
      expect(client).to receive(:repository).and_raise(exception)
    end

    it 'logs the original error' do
      expect(Gitlab::Import::Logger).to receive(:error).with({
        message: 'Import failed due to a GitHub error',
        status: 404,
        error: 'Not Found'
      }).and_call_original

      subject.execute(access_params, :github)
    end

    it 'returns an error with message and code' do
      result = subject.execute(access_params, :github)

      expect(result).to include(
        message: 'Import failed due to a GitHub error: Not Found (HTTP 404)',
        status: :error,
        http_status: :unprocessable_entity
      )
    end
  end

  it 'raises an exception for unknown error causes' do
    exception = StandardError.new('Not Implemented')

    expect(client).to receive(:repository).and_raise(exception)

    expect(Gitlab::Import::Logger).not_to receive(:error)

    expect { subject.execute(access_params, :github) }.to raise_error(exception)
  end

  context 'repository size validation' do
    let(:repository_double) { { name: 'repository', size: 99 } }

    before do
      allow(subject).to receive(:authorized?).and_return(true)
      expect(client).to receive(:repository).and_return(repository_double)

      allow_next_instance_of(Gitlab::LegacyGithubImport::ProjectCreator) do |creator|
        allow(creator).to receive(:execute).and_return(project_double)
      end
    end

    context 'when there is no repository size limit defined' do
      it 'skips the check, succeeds, and tracks an access level' do
        expect(subject.execute(access_params, :github)).to include(status: :success)
        expect(settings)
          .to have_received(:write)
          .with(optional_stages: nil,
            extended_events: true,
            timeout_strategy: timeout_strategy,
            prioritize_collaborators: true
          )
        expect_snowplow_event(
          category: 'Import::GithubService',
          action: 'create',
          label: 'import_access_level',
          user: user,
          extra: { import_type: 'github', user_role: 'Owner' }
        )
      end
    end

    context 'when the target namespace repository size limit is defined' do
      let_it_be(:group) { create(:group, repository_size_limit: 100) }

      before do
        params[:target_namespace] = group.full_path
      end

      it 'succeeds when the repository is smaller than the limit' do
        expect(subject.execute(access_params, :github)).to include(status: :success)
        expect(settings)
          .to have_received(:write)
          .with(
            optional_stages: nil,
            extended_events: true,
            timeout_strategy: timeout_strategy,
            prioritize_collaborators: true
          )
        expect_snowplow_event(
          category: 'Import::GithubService',
          action: 'create',
          label: 'import_access_level',
          user: user,
          extra: { import_type: 'github', user_role: 'Not a member' }
        )
      end

      it 'returns error when the repository is larger than the limit' do
        repository_double[:size] = 101

        expect(subject.execute(access_params, :github)).to include(size_limit_error)
      end
    end

    context 'when target namespace repository limit is not defined' do
      let_it_be(:group) { create(:group) }

      before do
        stub_application_setting(repository_size_limit: 100)
      end

      context 'when application size limit is defined' do
        it 'succeeds when the repository is smaller than the limit' do
          expect(subject.execute(access_params, :github)).to include(status: :success)
          expect(settings)
            .to have_received(:write)
            .with(
              optional_stages: nil,
              extended_events: true,
              timeout_strategy: timeout_strategy,
              prioritize_collaborators: true
            )
          expect_snowplow_event(
            category: 'Import::GithubService',
            action: 'create',
            label: 'import_access_level',
            user: user,
            extra: { import_type: 'github', user_role: 'Owner' }
          )
        end

        it 'returns error when the repository is larger than the limit' do
          repository_double[:size] = 101

          expect(subject.execute(access_params, :github)).to include(size_limit_error)
        end
      end
    end

    context 'when optional stages params present' do
      let(:optional_stages) do
        {
          single_endpoint_issue_events_import: true,
          single_endpoint_notes_import: 'false',
          attachments_import: false,
          collaborators_import: true
        }
      end

      it 'saves optional stages choice to import_data' do
        subject.execute(access_params, :github)

        expect(settings)
          .to have_received(:write)
          .with(
            optional_stages: optional_stages,
            extended_events: true,
            timeout_strategy: timeout_strategy,
            prioritize_collaborators: true
          )
      end
    end

    context 'when timeout strategy param is present' do
      let(:timeout_strategy) { 'pessimistic' }

      it 'saves timeout strategy to import_data' do
        subject.execute(access_params, :github)

        expect(settings)
          .to have_received(:write)
          .with(
            optional_stages: optional_stages,
            extended_events: true,
            timeout_strategy: timeout_strategy,
            prioritize_collaborators: true
          )
      end
    end

    context 'when additional access tokens are present' do
      it 'saves additional access tokens to import_data' do
        subject.execute(access_params, :github)

        expect(settings)
          .to have_received(:write)
          .with(
            optional_stages: optional_stages,
            extended_events: true,
            timeout_strategy: timeout_strategy,
            prioritize_collaborators: true
          )
      end
    end

    context 'when `github_import_extended_events` feature flag is disabled' do
      before do
        stub_feature_flags(github_import_extended_events: false)
      end

      it 'saves extend_events to import_data' do
        expect(settings)
          .to receive(:write)
          .with(a_hash_including(extended_events: false))

        subject.execute(access_params, :github)
      end
    end

    context 'when `prioritize_collaborators` feature flag is disabled' do
      before do
        stub_feature_flags(github_import_prioritize_collaborators: false)
      end

      it 'saves prioritize_collaborators to import_data' do
        expect(settings)
          .to receive(:write)
          .with(a_hash_including(prioritize_collaborators: false))

        subject.execute(access_params, :github)
      end
    end
  end

  context 'when import source is disabled' do
    let(:repository_double) do
      {
        name: 'vim',
        description: 'test',
        full_name: 'test/vim',
        clone_url: 'http://repo.com/repo/repo.git',
        private: false,
        has_wiki?: false
      }
    end

    before do
      stub_application_setting(import_sources: nil)
      allow(client).to receive(:repository).and_return(repository_double)
    end

    it 'returns forbidden' do
      result = subject.execute(access_params, :github)

      expect(result).to include(
        status: :error,
        http_status: :forbidden
      )
    end
  end

  context 'when a blocked/local URL is used as github_hostname' do
    let(:message) { 'Error while attempting to import from GitHub' }
    let(:error) { "Invalid URL: #{url}" }

    before do
      stub_application_setting(allow_local_requests_from_web_hooks_and_services: false)
    end

    where(url: %w[https://localhost https://10.0.0.1])

    with_them do
      it 'returns and logs an error' do
        allow(github_importer).to receive(:url).and_return(url)

        expect(Gitlab::Import::Logger).to receive(:error).with({
                                                                 message: message,
                                                                 error: error
                                                               }).and_call_original
        expect(github_importer.execute(access_params, :github)).to include(blocked_url_error(url))
      end
    end
  end

  context 'when target_namespace is blank' do
    before do
      params[:target_namespace] = ''
    end

    it 'raises an exception' do
      expect { subject.execute(access_params, :github) }.to raise_error(ArgumentError, 'Target namespace is required')
    end
  end

  context 'when namespace to import repository into does not exist' do
    before do
      params[:target_namespace] = 'unknown_path'
    end

    it 'returns an error' do
      expect(github_importer.execute(access_params, :github)).to include(not_existed_namespace_error)
    end
  end

  context 'when user has no permissions to import repository into the specified namespace' do
    let_it_be(:group) { create(:group) }

    before do
      params[:target_namespace] = group.full_path
    end

    it 'returns an error' do
      expect(github_importer.execute(access_params, :github)).to include(taken_namespace_error)
    end
  end

  def size_limit_error
    {
      status: :error,
      http_status: :unprocessable_entity,
      message: '"repository" size (101 B) is larger than the limit of 100 B.'
    }
  end

  def blocked_url_error(url)
    {
      status: :error,
      http_status: :bad_request,
      message: "Invalid URL: #{url}"
    }
  end

  def not_existed_namespace_error
    {
      status: :error,
      http_status: :unprocessable_entity,
      message: 'Namespace or group to import repository into does not exist.'
    }
  end

  def taken_namespace_error
    {
      status: :error,
      http_status: :unprocessable_entity,
      message: 'You are not allowed to import projects in this namespace.'
    }
  end
end
