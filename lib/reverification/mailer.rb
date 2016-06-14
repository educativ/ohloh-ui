module Reverification
  class Mailer
    extend Amazon
    FROM = 'info@openhub.net'.freeze
    MAX_ATTEMPTS = 3
    NOTIFICATION1_DUE_DAYS = 21
    NOTIFICATION2_DUE_DAYS = 140
    NOTIFICATION3_DUE_DAYS = 28
    NOTIFICATION4_DUE_DAYS = 14

    class << self
      def send_limit
        ses.quotas[:max_24_hour_send] - ses.quotas[:sent_last_24_hours]
      end

      def run
        resend_soft_bounced_notifications
        send_notifications
      end

      def send_notifications
        send_final_notification
        send_account_is_disabled_notification
        send_marked_for_disable_notification
        send_first_notification
      end

      def send_first_notification
        Account.reverification_not_initiated(send_limit).each do |account_id|
          account = Account.find(account_id)
          Reverification::Process.send_email(
            Reverification::Template.first_reverification_notice(account.email),
            account, 0
          )
        end
      end

      def send_marked_for_disable_notification
        ReverificationTracker.expired_initial_phase_notifications(send_limit).each do |rev_track|
          Reverification::Process.send_email(
            Reverification::Template.marked_for_disable_notice(rev_track.account.email),
            rev_track.account, 1
          )
        end
      end

      def send_account_is_disabled_notification
        ReverificationTracker.expired_second_phase_notifications(send_limit).each do |rev_track|
          Reverification::Process.send_email(
            Reverification::Template.account_is_disabled_notice(rev_track.account.email),
            rev_track.account, 2
          )
        end
      end

      def send_final_notification
        ReverificationTracker.expired_third_phase_notifications(send_limit).each do |rev_track|
          Reverification::Process.send_email(
            Reverification::Template.final_warning_notice(rev_track.account.email),
            rev_track.account, 3
          )
        end
      end

      def resend_soft_bounced_notifications
        # Grab all the soft_bounced trackers
        ReverificationTracker.soft_bounced_until_yesterday.max_attempts_not_reached
                             .limit(send_limit).each do |rev_track|
          Reverification::Process.send_email(rev_track.template_hash, rev_track.account, rev_track.phase_value)
        end
      end
    end
  end
end
