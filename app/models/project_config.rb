class ProjectConfig
  KEYS = [:frequency, :ruby, :rake_task]
  attr_accessor :frequency, :ruby, :rake_task, :environment_variables

  def initialize
    @frequency = 20
    @ruby = RUBY_VERSION
    @rake_task = :default
    @environment_variables = {}
    @after_build = []
  end

  def environment_string
    @environment_variables.each_pair.map { |k, v| "#{k}=#{v}" }.join(" ")
  end

  def after_build(*args)
    @after_build = args unless args.empty?
    @after_build
  end
end
