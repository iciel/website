class GenerateIterationSnippetJob < ApplicationJob
  extend Mandate::Memoize

  queue_as :snippets

  def perform(iteration)
    # Sometimes the iteration might be deleted
    # before we get to the job. There *shouldn't* be
    # a DB race condition because of the way this is called
    # in Iteration::Create but if we see missing snippets,
    # that's probably worth investigating
    return unless iteration

    file = iteration.submission.files.first
    return unless file

    snippet = RestClient.post(
      snippet_generator_url,
      {
        language: iteration.track.slug,
        source_code: file.content
      }.to_json,
      { content_type: :json, accept: :json }
    ).body

    snippet = "#{snippet[0, 1400]}\n\n..." if snippet.length > 1400

    iteration.update_column(:snippet, snippet)
    iteration.solution.update_column(:snippet, snippet) if should_update_solution?(iteration)
  rescue JSON::GeneratorError => e
    # Silently drop things where we can't parse characters in the resulting JSON.
    # This is going to be down to unicode issues
    return if e.message.include?("Invalid Unicode")

    raise
  end

  private
  def should_update_solution?(iteration)
    solution = iteration.solution
    return true if solution.published_iteration_id == iteration.id

    solution.published_iteration_id.nil? && solution.latest_iteration == iteration
  end

  def snippet_generator_url
    Exercism.config.tooling_snippet_generator_url
  end
end
