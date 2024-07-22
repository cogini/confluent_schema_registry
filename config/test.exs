import Config

# config :logger, level: :debug
# config :logger,
#   level: :debug,
#   backends: [:console],
#   compile_time_purge_level: :debug

config :junit_formatter,
  report_dir: "#{Mix.Project.build_path()}/junit-reports",
  automatic_create_dir?: true,
  print_report_file: true,
  # prepend_project_name?: true,
  include_filename?: true,
  include_file_line?: true
