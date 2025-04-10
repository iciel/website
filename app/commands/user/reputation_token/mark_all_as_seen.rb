class User::ReputationToken
  class MarkAllAsSeen
    include Mandate

    initialize_with :user

    def call
      ActiveRecord::Base.transaction(isolation: Exercism::READ_COMMITTED) do
        num_changed = user.reputation_tokens.unseen.
          update_all(seen: true)

        ReputationChannel.broadcast_changed!(user) if num_changed.positive?
      end
    end
  end
end
