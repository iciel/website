module Git
  class Track
    extend Mandate::Memoize
    extend Git::HasGitFilepath

    delegate :head_sha, :fetch!, :lookup_commit, :head_commit, to: :repo

    git_filepath :about, file: "docs/ABOUT.md"
    git_filepath :snippet, file: "docs/SNIPPET.txt"
    git_filepath :debugging_instructions, file: "exercises/shared/.docs/debug.md"
    git_filepath :help, file: "exercises/shared/.docs/help.md"
    git_filepath :tests, file: "exercises/shared/.docs/tests.md"
    git_filepath :config, file: "config.json"

    def initialize(git_sha = "HEAD", repo_url: nil, repo: nil)
      raise "One of :repo or :repo_url must be specified" unless [repo, repo_url].compact.size == 1

      @repo = repo || Repository.new(repo_url: repo_url)
      @git_sha = git_sha
    end

    memoize
    def title
      config[:language]
    end

    memoize
    def slug
      config[:slug]
    end

    memoize
    def blurb
      config[:blurb]
    end

    memoize
    def tags
      config[:tags].to_a
    end

    memoize
    def active?
      !!config[:active]
    end

    memoize
    def key_features
      config[:key_features].to_a
    end

    memoize
    def has_concept_exercises?
      !!config[:status][:concept_exercises]
    end

    memoize
    def has_test_runner?
      !!config[:status][:test_runner]
    end

    memoize
    def has_representer?
      config[:status][:representer]
    end

    memoize
    def has_analyzer?
      config[:status][:analyzer]
    end

    memoize
    def concept_exercises
      config[:exercises][:concept].to_a
    end

    memoize
    def practice_exercises
      config[:exercises][:practice].to_a
    end

    memoize
    def concepts
      config[:concepts].to_a
    end

    memoize
    def indent_style
      (online_editor[:indent_style] || 'space').to_sym
    end

    memoize
    def indent_size
      online_editor[:indent_size] || 2
    end

    memoize
    def ace_editor_language
      online_editor[:ace_editor_language]
    end

    memoize
    def highlightjs_language
      online_editor[:highlightjs_language]
    end

    memoize
    def average_test_duration
      test_runner[:average_run_time] || 3.0
    end

    memoize
    def commit
      repo.lookup_commit(git_sha)
    end

    def find_exercise(uuid)
      find_concept_exercise(uuid) || find_practice_exercise(uuid)
    end

    def find_concept_exercise(uuid)
      concept_exercises.find { |e| e[:uuid] == uuid }
    end

    def find_practice_exercise(uuid)
      practice_exercises.find { |e| e[:uuid] == uuid }
    end

    def find_concept(uuid)
      concepts.find { |c| c[:uuid] == uuid }
    end

    memoize
    def taught_concept_slugs
      concept_slugs = concepts.map { |c| c[:slug] }
      concept_exercise_concept_slugs = concept_exercises.flat_map { |e| e[:concepts].to_a }
      concept_exercise_concept_slugs & concept_slugs
    end

    private
    attr_reader :repo, :git_sha

    def absolute_filepath(filepath)
      filepath
    end

    memoize
    def online_editor
      config[:online_editor] || {}
    end

    memoize
    def test_runner
      config[:test_runner] || {}
    end
  end
end
