return unless Rails.env.development?

Rake::Task.define_task("db:migrate": :environment) do
  AnnotateRb::ModelAnnotator::Annotator.do_annotations(models: true)
end
