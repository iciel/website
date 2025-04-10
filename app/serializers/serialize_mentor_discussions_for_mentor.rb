class SerializeMentorDiscussionsForMentor
  include Mandate

  initialize_with :discussions, :mentor

  def call
    discussions.
      includes(:solution, :exercise, :track, :student, :mentor).
      map { |d| SerializeMentorDiscussionForMentor.(d, relationship: relationships[d.student.id]) }
  end

  memoize
  def relationships
    Mentor::StudentRelationship.where(mentor: mentor, student_id: discussions.joins(:solution).pluck(:user_id)).
      index_by(&:student_id)
  end
end
