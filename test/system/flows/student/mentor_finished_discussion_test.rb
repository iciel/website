require "application_system_test_case"
require_relative "../../../support/capybara_helpers"

module Flows
  module Student
    class MentorFinishedDiscussionTest < ApplicationSystemTestCase
      include CapybaraHelpers

      test "end discussion button does not show" do
        student = create :user, handle: "student"
        track = create :track
        exercise = create :concept_exercise, track: track
        solution = create :concept_solution, user: student, exercise: exercise
        request = create :mentor_request, solution: solution
        discussion = create :mentor_discussion,
          status: :mentor_finished,
          solution: solution,
          request: request
        submission = create :submission, solution: solution
        create :iteration, idx: 1, solution: solution, submission: submission

        use_capybara_host do
          sign_in!(student)
          visit track_exercise_mentor_discussion_path(track, exercise, discussion)
        end

        assert_text "Ended"
      end

      test "student reviews discussion" do
        user = create :user
        track = create :track
        create :user_track, user: user, track: track
        exercise = create :concept_exercise, track: track
        solution = create :concept_solution, exercise: exercise, user: user
        submission = create :submission, solution: solution,
          tests_status: :passed,
          representation_status: :generated,
          analysis_status: :completed
        create :iteration, idx: 1, solution: solution, submission: submission
        discussion = create :mentor_discussion, solution: solution, status: :mentor_finished

        use_capybara_host do
          sign_in!(user)
          visit track_exercise_mentor_discussion_path(solution.track, solution.exercise, discussion)
          click_on "Review & finish discussion"
          within(".m-confirm-finish-student-mentor-discussion") { click_on "Review and end discussion" }
          click_on "It was good!"
          fill_in "Leave #{discussion.mentor.handle} a testimonial (optional)", with: "Good mentor!"
          click_on "Finish"
          click_on "Back to the exercise"

          assert_text "Nice, it looks like you’re done here!"
        end
      end
    end
  end
end
