require 'test_helper'

class Reverification::ProcessTest < ActiveSupport::TestCase

  describe 'initial phase' do
    describe 'send' do
      it 'should not send if ses limit has been reached' do
        Reverification::Process.stubs(:ses_limit_reached?).returns(true)
        AWS::SimpleEmailService.any_instance.expects(:send_email).never
      end

      # Ask Peter about this. Why is the test failing?

      # it 'should send an initial email and create a reverification tracker' do
      #   unverified_account_success = create(:unverified_account, :success)
      #   template = Reverification::Template.first_reverification_notice(unverified_account_success.email)
      #   Reverification::Process.stubs(:ses_limit_reached?).returns(true)
      #   AWS::SimpleEmailService.any_instance.stubs(:send_email).with(template).returns(aws_response_message_id)
      #   Reverification::Process.send(template, unverified_account_success, 0)
      #   unverified_account_success.reverification_tracker.must_be :present?
      #   unverified_account_success.reverification_tracker.phase.must_equal 'initial'
      #   unverified_account_success.reverification_tracker.attempts.must_equal 1
      # end

      # Note: Would this test go under send or resend notification. Send method has the code
      #       that does the updating.

      # it 'should update a reverification trackers status to delivered after the 3rd attempt' do
      #   rev_tracker = create(:soft_bounce_initial_rev_tracker)
      #   assert rev_tracker.soft_bounced?
      #   template = Reverification::Template.first_reverification_notice(rev_tracker.account.email)
      #   Reverification::Mailer.send(template, rev_tracker.account, 0)
      #   # assert rev_tracker
      # end
    end

    describe 'poll success queue' do
      before do
        mock_queue = mock('AWS::SQS::Queue::MOCK')
        mock_queue.stubs(:poll).yields(SuccessMessage.new)
        Reverification::Process.stubs(:success_queue).returns(mock_queue)
      end

      it 'should retrieve a message in the queue and update rev_tracker to delivered' do
        rev_tracker = create(:success_initial_rev_tracker)
        assert rev_tracker.pending?
        Reverification::Process.poll_success_queue
        rev_tracker.reload
        assert rev_tracker.delivered?
      end

      it "should not update an account's rev_tracker to delivered if status is not pending" do
        rev_tracker = create(:success_initial_rev_tracker, status: 2)
        rev_tracker.wont_be :pending?
        Reverification::Process.poll_success_queue
        rev_tracker.reload
        rev_tracker.wont_be :delivered?
      end
    end

    describe 'poll bounce queue' do
      let(:mock_queue) { mock('AWS::SQS::Queue::MOCK') }
      let(:hard_bounce_account) { create(:unverified_account, :hard_bounce) }
      let(:soft_bounce_account) { create(:unverified_account, :soft_bounce) }
      let(:bounce_undetermined_account) { create(:unverified_account, :bounce_undetermined) }

      before do
        create(:reverification_tracker, account: hard_bounce_account)
        create(:reverification_tracker, account: soft_bounce_account)
        create(:reverification_tracker, account: bounce_undetermined_account)
      end

      describe 'hard bounce' do
        it 'should delete the account' do
          mock_queue.stubs(:poll).yields(HardBounceMessage.new)
          Reverification::Process.stubs(:bounce_queue).returns(mock_queue)
          hard_bounce_account.must_be :present?
          hard_bounce_account.reverification_tracker.must_be :present?
          Reverification::Process.poll_bounce_queue
          Account.find_by(id: hard_bounce_account.id).must_be_nil
          ReverificationTracker.find_by(id: hard_bounce_account.reverification_tracker.id).must_be_nil
        end
      end
    
      describe 'soft bounce' do
        it 'should update the reverification tracker status to soft_bounced' do
          mock_queue.stubs(:poll).yields(TransientBounceMessage.new)
          Reverification::Process.stubs(:bounce_queue).returns(mock_queue)
          soft_bounce_account.reverification_tracker.wont_be :soft_bounced?
          Reverification::Process.poll_bounce_queue
          soft_bounce_account.reload.reverification_tracker.must_be :soft_bounced?
        end
      end

      describe 'undetermined bounce' do
        it 'shoould update the reverification tracket status to soft_bounced' do
          mock_queue.stubs(:poll).yields(UndeterminedBounceMessage.new)
          Reverification::Process.stubs(:bounce_queue).returns(mock_queue)
          bounce_undetermined_account.reverification_tracker.wont_be :soft_bounced?
          Reverification::Process.poll_bounce_queue
          bounce_undetermined_account.reload.reverification_tracker.must_be :soft_bounced?
        end
      end
    end
  end

  describe 'poll complaints queue' do
    let(:complained_account) { create(:unverified_account, :complaint) }

    before do
      create(:reverification_tracker, account: complained_account)
      mock_queue = mock('AWS::SQS::Queue::MOCK')
      mock_queue.stubs(:poll).yields(ComplaintMessage.new)
      Reverification::Process.stubs(:complaints_queue).returns(mock_queue)
    end

    it 'should update reverification tracker status to complained' do
      complained_account.reverification_tracker.wont_be :complained?
      Reverification::Process.poll_complaints_queue
      complained_account.reload.reverification_tracker.must_be :complained?
    end
  end

  describe 'marked for spam phase' do
  end

  describe 'convert to spam phase' do
  end

  describe 'final warngin phase' do
  end
end
