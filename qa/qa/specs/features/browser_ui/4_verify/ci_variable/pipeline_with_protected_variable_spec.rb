# frozen_string_literal: true

module QA
  RSpec.describe 'Verify', :runner, product_group: :pipeline_security do
    describe 'Pipeline with protected variable' do
      let(:executor) { "qa-runner-#{Faker::Alphanumeric.alphanumeric(number: 8)}" }
      let(:protected_value) { Faker::Alphanumeric.alphanumeric(number: 8) }
      let(:project) { create(:project, name: 'project-with-ci-vars', description: 'project with CI vars') }
      let!(:runner) { create(:project_runner, project: project, name: executor, tags: [executor]) }
      let!(:ci_file) do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              job:
                tags:
                  - #{executor}
                script: echo $PROTECTED_VARIABLE
            YAML
          }
        ])
      end

      let(:developer) do
        Resource::User.fabricate_or_use(Runtime::Env.gitlab_qa_username_1, Runtime::Env.gitlab_qa_password_1)
      end

      let(:maintainer) do
        Resource::User.fabricate_or_use(Runtime::Env.gitlab_qa_username_2, Runtime::Env.gitlab_qa_password_2)
      end

      before do
        Flow::Login.sign_in
        project.visit!
        project.add_member(developer)
        project.add_member(maintainer, Resource::Members::AccessLevel::MAINTAINER)
        add_ci_variable
      end

      after do
        runner.remove_via_api!
      end

      it 'exposes variable on protected branch', :reliable,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348005' do
        create_protected_branch

        [developer, maintainer].each do |user|
          user_commit_to_protected_branch(Runtime::API::Client.new(:gitlab, user: user))
          go_to_pipeline_job(user)

          Page::Project::Job::Show.perform do |show|
            expect(show.output).to have_content(protected_value), 'Expect protected variable to be in job log.'
          end
        end
      end

      it 'does not expose variable on unprotected branch', :reliable,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347664' do
        [developer, maintainer].each do |user|
          create_merge_request(Runtime::API::Client.new(:gitlab, user: user))
          go_to_pipeline_job(user)

          Page::Project::Job::Show.perform do |show|
            expect(show.output).to have_no_content(protected_value), 'Expect protected variable to NOT be in job log.'
          end
        end
      end

      private

      def add_ci_variable
        create(:ci_variable, :protected, project: project, key: 'PROTECTED_VARIABLE', value: protected_value)
      end

      def create_protected_branch
        # Using default setups, which allows access for developer and maintainer
        create(:protected_branch, branch_name: 'protected-branch', project: project)
      end

      def user_commit_to_protected_branch(api_client)
        # Retry is needed due to delays with project authorization updates
        # Long term solution to accessing the status of a project authorization update
        # has been proposed in https://gitlab.com/gitlab-org/gitlab/-/issues/393369
        Support::Retrier.retry_until(
          max_duration: 60,
          sleep_interval: 1,
          message: "Commit to protected branch failed",
          retry_on_exception: true
        ) do
          create(:commit,
            api_client: api_client,
            project: project,
            branch: 'protected-branch',
            commit_message: Faker::Lorem.sentence, actions: [
              { action: 'create', file_path: Faker::File.unique.file_name, content: Faker::Lorem.sentence }
            ])
        end
      end

      def create_merge_request(api_client)
        # Retry is needed due to delays with project authorization updates
        # Long term solution to accessing the status of a project authorization update
        # has been proposed in https://gitlab.com/gitlab-org/gitlab/-/issues/393369
        Support::Retrier.retry_until(
          max_duration: 60,
          sleep_interval: 1,
          message: "MR fabrication failed after retry",
          retry_on_exception: true
        ) do
          create(:merge_request,
            api_client: api_client,
            project: project,
            description: Faker::Lorem.sentence,
            target_new_branch: false,
            file_name: Faker::File.unique.file_name,
            file_content: Faker::Lorem.sentence)
        end
      end

      def go_to_pipeline_job(user)
        Flow::Login.sign_in(as: user)
        project.visit!
        Flow::Pipeline.visit_latest_pipeline

        Page::Project::Pipeline::Show.perform do |pipeline|
          pipeline.click_job('job')
        end
      end
    end
  end
end
