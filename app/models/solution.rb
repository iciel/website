class Solution < ApplicationRecord
  extend Mandate::Memoize

  OPENSEARCH_INDEX = "#{Rails.env}-solutions".freeze

  enum mentoring_status: { none: 0, requested: 1, in_progress: 2, finished: 3 }, _prefix: 'mentoring'
  enum status: { started: 0, iterated: 1, completed: 2, published: 3 }, _prefix: true
  enum published_iteration_head_tests_status: { not_queued: 0, queued: 1, passed: 2, failed: 3, errored: 4, exceptioned: 5, cancelled: 6 }, _prefix: true # rubocop:disable Layout/LineLength
  enum latest_iteration_head_tests_status: { not_queued: 0, queued: 1, passed: 2, failed: 3, errored: 4, exceptioned: 5, cancelled: 6 }, _prefix: true # rubocop:disable Layout/LineLength

  belongs_to :user
  belongs_to :exercise
  belongs_to :published_iteration, class_name: "Iteration", optional: true
  has_one :track, through: :exercise

  # TODO: This might be horrific for performance
  has_one :user_track, # rubocop:disable Rails/HasManyOrHasOneDependent
    lambda { |s|
      joins(track: :exercises).
        where('exercises.id': s.exercise_id)
    },
    foreign_key: :user_id,
    primary_key: :user_id,
    touch: :last_touched_at,
    inverse_of: :solutions

  has_many :submissions, dependent: :destroy
  has_many :iterations, dependent: :destroy
  has_many :user_activities, class_name: "User::Activity", dependent: :destroy

  # rubocop:disable Rails/HasManyOrHasOneDependent
  has_one :latest_iteration, -> { where(deleted_at: nil).order('id DESC') }, class_name: "Iteration" # rubocop:disable Rails/InverseOf
  # rubocop:enable Rails/HasManyOrHasOneDependent

  has_many :comments, dependent: :destroy
  has_many :stars, dependent: :destroy

  has_many :mentor_requests, class_name: "Mentor::Request", dependent: :destroy
  has_many :mentor_discussions, class_name: "Mentor::Discussion", dependent: :destroy
  has_many :mentors, through: :mentor_discussions

  scope :completed, -> { where.not(completed_at: nil) }
  scope :not_completed, -> { where(completed_at: nil) }

  scope :published, -> { where.not(published_at: nil) }
  scope :not_published, -> { where(published_at: nil) }

  delegate :files_for_editor, to: :exercise, prefix: :exercise

  before_create do
    # Search engines derive meaning by using hyphens
    # as word-boundaries in URLs. Since we use the
    # solution UUID for URLs, we're removing the hyphen
    # to remove any spurious, accidental, and arbitrary
    # meaning.
    self.uuid = SecureRandom.compact_uuid unless self.uuid
    self.public_uuid = SecureRandom.compact_uuid unless self.public_uuid
    self.unique_key = "#{user_id}:#{exercise_id}"

    self.git_slug = exercise.slug unless self.git_slug
    self.git_sha = exercise.git_sha unless self.git_sha
    self.git_important_files_hash = exercise.git_important_files_hash if self.git_important_files_hash.blank?
  end

  before_update do
    self.status = determine_status
  end

  after_save do
    SyncSolutionToSearchIndexJob.perform_later(self)
  end

  after_update do
    # It's basically never bad to run this.
    # There should always be a head test run and if there's
    # not we should make one. 99% of the time this will result
    # in a no-op
    QueueSolutionHeadTestRunJob.perform_later(self)
  end

  def self.for!(*args)
    solution = self.for(*args)
    solution || raise(ActiveRecord::RecordNotFound)
  end

  def self.for(*args)
    if args.size == 2
      user, exercise = args
      find_by(user: user, exercise: exercise)
    else
      user_handle, track_slug, exercise_slug = args
      joins(:user, exercise: :track).find_by(
        'users.handle': user_handle,
        'tracks.slug': track_slug,
        'exercises.slug': exercise_slug
      )
    end
  end

  delegate :instructions, :introduction, :tests, :source, :source_url, to: :git_exercise

  def update_published_iteration_head_tests_status!(status)
    return if published_iteration_head_tests_status == status.to_sym

    update_column(:published_iteration_head_tests_status, status)
    SyncSolutionToSearchIndexJob.perform_later(self)
  end

  def update_latest_iteration_head_tests_status!(status)
    return if latest_iteration_head_tests_status == status.to_sym

    update_column(:latest_iteration_head_tests_status, status)
    SyncSolutionToSearchIndexJob.perform_later(self)
  end

  memoize
  def latest_published_iteration_submission
    published_iterations.last&.submission
  end

  memoize
  def latest_iteration_submission
    latest_iteration&.submission
  end

  def mentor_download_cmd
    "exercism download --uuid=#{uuid}"
  end

  def viewable_by?(viewer)
    # A user can always see their own stuff
    return true if self.user_id == viewer&.id

    # Current mentors can see submissions
    return true if viewer && self.mentors.include?(viewer)

    # All mentors can see files on pending requests
    return true if viewer && self.mentor_requests.pending.any? && viewer.mentor?

    # Everyone can see published iterations
    published?
  end

  def starred_by?(user)
    stars.exists?(user: user)
  end

  def published_iterations
    return [] unless published?
    return [published_iteration] if published_iteration && !published_iteration.deleted?

    iterations.not_deleted
  end

  memoize
  # Submissions that have the tests cancelled should never be
  # show to a user. This is the submission we show in the editor by default.
  def latest_submission
    submissions.where.not(tests_status: :cancelled).last
  end

  memoize
  # Submissions that exception are not considered valid.
  # We use this to calculate which solutions someone may submit
  # mutliple times in a row (e.g. if they clicked cancel or the
  # test-runner failed, they should be able to resubmit)
  def latest_valid_submission
    submissions.where.not(
      tests_status: %i[cancelled exceptioned]
    ).last
  end

  %i[status mentoring_status
     published_iteration_head_tests_status
     latest_iteration_head_tests_status].each do |meth|
    define_method meth do
      super().to_sym
    end
  end

  def iteration_status
    super&.to_sym
  end

  # TODO: Karlo
  def has_unsubmitted_code?
    false
  end

  def git_type
    self.class.name.sub("Solution", "").downcase
  end

  def to_param
    raise "We almost never want to auto-generate solution urls. Use the solution_url helper method or use uuid if you're sure you want to do this." # rubocop:disable Layout/LineLength
  end

  def downloaded?
    !!downloaded_at
  end

  def completed?
    !!completed_at
  end

  def published?
    !!published_at
  end

  def iterated?
    iterations.exists?
  end

  def has_unlocked_pending_mentoring_request?
    mentor_requests.pending.unlocked.exists?
  end

  def has_locked_pending_mentoring_request?
    mentor_requests.pending.locked.exists?
  end

  memoize
  def in_progress_mentor_discussion
    mentor_discussions.in_progress_for_student.first
  end

  def update_status!
    new_status = determine_status
    update(status: new_status) if status != new_status
  end

  def update_iteration_status!
    new_status = iterations.last&.status.to_s
    update_column(:iteration_status, new_status) if iteration_status != new_status
  end

  def update_mentoring_status!
    new_status = determine_mentoring_status
    update(mentoring_status: new_status) if mentoring_status != new_status
  end

  def out_of_date?
    git_important_files_hash != exercise.git_important_files_hash
  end

  def external_mentoring_request_url
    Exercism::Routes.mentoring_external_request_url(public_uuid)
  end

  def files_for_editor
    submission = submissions.last
    return exercise.files_for_editor unless submission

    submission.files_for_editor
  end

  def broadcast!
    SolutionChannel.broadcast!(self)
    LatestIterationStatusChannel.broadcast!(self)
  end

  def anonymised_user_handle
    "anonymous-#{Digest::SHA1.hexdigest("#{id}-#{uuid}")}"
  end

  def sync_git!
    update!(
      git_slug: exercise.slug,
      git_sha: exercise.git_sha,
      git_important_files_hash: exercise.git_important_files_hash
    )
  end

  def read_file(filepath)
    return Solution::GenerateReadmeFile.(self) if filepath == Git::Exercise::SPECIAL_FILEPATHS[:readme]
    return Solution::GenerateHelpFile.(self) if filepath == Git::Exercise::SPECIAL_FILEPATHS[:help]
    return Solution::GenerateHintsFile.(self) if filepath == Git::Exercise::SPECIAL_FILEPATHS[:hints]
    return git_exercise.read_file_blob(exercise.git.config_filepath) if filepath == Git::Exercise::SPECIAL_FILEPATHS[:config]

    git_exercise.read_file_blob(filepath)
  end

  memoize
  def git_exercise
    Git::Exercise.for_solution(self)
  end

  private
  def determine_status
    return :published if published?
    return :completed if completed?
    return :iterated if iterated?

    :started
  end

  def determine_mentoring_status
    return :in_progress if mentor_discussions.in_progress_for_student.exists?
    return :requested if mentor_requests.pending.exists?
    return :finished if mentor_discussions.finished_for_student.exists?

    :none
  end
end
