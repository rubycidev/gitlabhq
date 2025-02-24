# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Git::WrapsGitalyErrors, feature_category: :gitaly do
  subject(:wrapper) do
    klazz = Class.new { include Gitlab::Git::WrapsGitalyErrors }
    klazz.new
  end

  describe "#wrapped_gitaly_errors" do
    where(:original_error, :wrapped_error) do
      [
        [GRPC::InvalidArgument, ArgumentError],
        [GRPC::DeadlineExceeded, Gitlab::Git::CommandTimedOut],
        [GRPC::BadStatus, Gitlab::Git::CommandError]
      ]
    end

    with_them do
      it "wraps #{params[:original_error]} in a #{params[:wrapped_error]}" do
        expect { wrapper.wrapped_gitaly_errors { raise original_error, 'wrapped' } }
          .to raise_error(wrapped_error)
      end
    end

    context 'when wrap GRPC::ResourceExhausted' do
      context 'with Gitaly::LimitError detail' do
        let(:original_error) do
          new_detailed_error(
            GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED,
            'resource exhausted',
            Gitaly::LimitError.new(
              error_message: "maximum time in concurrency queue reached",
              retry_after: Google::Protobuf::Duration.new(seconds: 5, nanos: 1500)
            )
          )
        end

        it "wraps in a Gitlab::Git::ResourceExhaustedError with error message" do
          expect { wrapper.wrapped_gitaly_errors { raise original_error } }.to raise_error do |wrapped_error|
            expect(wrapped_error).to be_a(Gitlab::Git::ResourceExhaustedError)
            expect(wrapped_error.message).to eql(
              "Upstream Gitaly has been exhausted: maximum time in concurrency queue reached. Try again later"
            )
            expect(wrapped_error.headers).to eql({ 'Retry-After' => 5 })
          end
        end
      end

      context 'with Gitaly::LimitError detail without retry after' do
        let(:original_error) do
          new_detailed_error(
            GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED,
            'resource exhausted',
            Gitaly::LimitError.new(error_message: "maximum time in concurrency queue reached")
          )
        end

        it "wraps in a Gitlab::Git::ResourceExhaustedError with error message" do
          expect { wrapper.wrapped_gitaly_errors { raise original_error } }.to raise_error do |wrapped_error|
            expect(wrapped_error).to be_a(Gitlab::Git::ResourceExhaustedError)
            expect(wrapped_error.message).to eql(
              "Upstream Gitaly has been exhausted: maximum time in concurrency queue reached. Try again later"
            )
            expect(wrapped_error.headers).to eql({})
          end
        end
      end

      context 'without Gitaly::LimitError detail' do
        it("wraps in a Gitlab::Git::ResourceExhaustedError with default message") {
          expect { wrapper.wrapped_gitaly_errors { raise GRPC::ResourceExhausted } }.to raise_error do |wrapped_error|
            expect(wrapped_error).to be_a(Gitlab::Git::ResourceExhaustedError)
            expect(wrapped_error.message).to eql("Upstream Gitaly has been exhausted. Try again later")
            expect(wrapped_error.headers).to eql({})
          end
        }
      end
    end

    shared_examples 'commit not found' do |message|
      it 'wraps the commit not found error' do
        expect { wrapped_gitaly_errors }.to raise_error do |wrapped_error|
          expect(wrapped_error).to be_a(Gitlab::Git::Repository::CommitNotFound)
          expect(wrapped_error.message).to eql(message)
        end
      end
    end

    context 'when receiving GRPC::Core::StatusCodes::NOT_FOUND' do
      subject(:wrapped_gitaly_errors) { wrapper.wrapped_gitaly_errors { raise original_error } }

      let(:original_error) do
        new_detailed_error(
          GRPC::Core::StatusCodes::NOT_FOUND,
          'commits not found',
          Gitaly::FindCommitsError.new(commit_error)
        )
      end

      context 'with Gitaly::FindCommitsError contains Gitaly::AmbiguousReferenceError detail' do
        let(:commit_error) do
          { ambiguous_ref: Gitaly::AmbiguousReferenceError.new(reference: 'non-existing-ref') }
        end

        it_behaves_like 'commit not found', 'ambiguous reference:non-existing-ref'
      end

      context 'with Gitaly::FindCommitsError contains Gitaly::BadObjectError detail' do
        let(:commit_error) do
          { bad_object: Gitaly::BadObjectError.new(bad_oid: '0b4bc9a49b562e85de7cc9e834518ea6828729b9') }
        end

        it_behaves_like 'commit not found', 'bad object:0b4bc9a49b562e85de7cc9e834518ea6828729b9'
      end

      context 'with Gitaly::FindCommitsError contains Gitaly::InvalidRevisionRange detail' do
        let(:commit_error) do
          { invalid_range: Gitaly::InvalidRevisionRange.new(range: '0b4bc9a49b562e85de7cc9e834518ea6828729b9') }
        end

        it_behaves_like 'commit not found', 'invalid range:0b4bc9a49b562e85de7cc9e834518ea6828729b9'
      end

      context 'with non Gitaly::FindCommitsError' do
        let(:original_error) { GRPC::NotFound }

        it 'wraps in a Gitlab::Git::Repository::NoRepository' do
          expect { wrapped_gitaly_errors }.to raise_error do |wrapped_error|
            expect(wrapped_error).to be_a(Gitlab::Git::Repository::NoRepository)
          end
        end
      end
    end

    it 'does not swallow other errors' do
      expect { wrapper.wrapped_gitaly_errors { raise 'raised' } }
        .to raise_error(RuntimeError)
    end
  end

  context 'when wrap GRPC::NotFound' do
    context 'with Gitaly::ReferenceNotFoundError detail' do
      let(:original_error) do
        new_detailed_error(
          GRPC::Core::StatusCodes::NOT_FOUND,
          'not found',
          Gitaly::ReferenceNotFoundError.new(reference_name: "foobar")
        )
      end

      it "wraps in a Gitlab::Git::ReferenceNotFoundError" do
        expect { wrapper.wrapped_gitaly_errors { raise original_error } }.to raise_error do |wrapped_error|
          expect(wrapped_error).to be_a(Gitlab::Git::ReferenceNotFoundError)
          expect(wrapped_error.name).to eql("foobar")
        end
      end
    end

    context 'without detail' do
      let(:original_error) do
        GRPC::NotFound
      end

      it "wraps in a Gitlab::Git::Repository::NoRepository" do
        expect { wrapper.wrapped_gitaly_errors { raise original_error } }.to raise_error do |wrapped_error|
          expect(wrapped_error).to be_a(Gitlab::Git::Repository::NoRepository)
        end
      end
    end
  end
end
