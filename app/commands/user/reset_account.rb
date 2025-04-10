class User
  class ResetAccount
    include Mandate

    initialize_with :user

    def call
      reset_tracks!
      reset_mentoring!
      reset_associations!
      reassign_to_ghost!

      user.update(
        reputation: 0,
        roles: [],
        bio: nil,
        avatar_url: nil,
        location: nil,
        pronouns: nil,
        became_mentor_at: nil
      )
    end

    def reset_tracks!
      # If someone has submitted solutions then left a user track,
      # then we won't reset those solutions and things will break.
      # So we need to temporarily recreate the user tracks here.
      existing_track_ids = user.user_tracks.pluck(:track_id)
      user.solutions.joins(:exercise).distinct.pluck(:track_id).each do |track_id|
        next if existing_track_ids.include?(track_id)

        UserTrack.create!(user: user, track_id: track_id)
      end

      user.user_tracks.each do |user_track|
        UserTrack::Destroy.(user_track)
      end
    end

    def reset_mentoring!
      Mentor::Request.where(student_id: user.id).pending.delete_all
      Mentor::Request.where(student_id: user.id).update_all(student_id: User::GHOST_USER_ID)

      user.mentor_discussions.update_all(mentor_id: User::GHOST_USER_ID)
      user.mentor_discussion_posts.update_all(user_id: User::GHOST_USER_ID)
      user.mentor_testimonials.update_all(mentor_id: User::GHOST_USER_ID)
      user.provided_testimonials.update_all(student_id: User::GHOST_USER_ID)
    end

    def reassign_to_ghost!
      user.problem_reports.update_all(user_id: User::GHOST_USER_ID)
    end

    def reset_associations!
      user.profile&.destroy
      user.activities.delete_all
      user.notifications.delete_all
      user.reputation_tokens.delete_all
      user.reputation_periods.delete_all
      user.acquired_badges.delete_all
      user.track_mentorships.delete_all
      user.scratchpad_pages.delete_all
      user.solution_stars.delete_all
    end
  end
end
