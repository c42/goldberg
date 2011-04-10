require "spec_helper"

module Goldberg
  describe Project do
    before(:each) do
      Paths.stub!(:projects).and_return('some_path')
    end

    describe "lifecycle" do
      context "adding a project" do
        it "creates a new projects and checks out the code for it" do
          Environment.should_receive(:system).with('git clone --depth 1 git://some.url.git some_path/some_project/code').and_return(true)
          lambda { Project.add({:url => "git://some.url.git", :name => 'some_project'}) }.should change(Project, :count).by(1)
        end

        it "creates a new project with spaces in the name" do
          Environment.should_receive(:system).with('git clone --depth 1 git://some.url.git some_path/some_project/code').and_return(true)
          lambda { Project.add({:url => "git://some.url.git", :name => 'some project'}) }.should change(Project, :count).by(1)
        end

      end

      context "removing project" do
        let(:project){ Factory(:project, :name => 'project_to_be_removed') }

        it "removes it from the DB" do
          project.destroy
          Project.find_by_name('project_to_be_removed').should be_nil
        end

        it "removes the checked out code and build info from filesystem" do
          FileUtils.should_receive(:rm_rf).with(project.path)
          project.destroy
        end

        it "removes all the builds from DB" do
          build = project.builds.create
          project.destroy
          Build.find_by_id(build.id).should be_nil
        end
      end
    end

    context "checkout" do
      it "checks out the code for the project" do
        project = Project.new(:url => "git://some.url.git", :name => 'some_project')
        Environment.should_receive(:system).with('git clone --depth 1 git://some.url.git some_path/some_project/code').and_return(true)
        project.checkout
      end
    end

    context "delegation to latest build" do
      [:number, :status, :log, :timestamp].each do |field|
        it "delegates latest_build_#{field} to the latest build" do
          project = Project.new
          latest_build = mock(Build)
          latest_build.should_receive(field)
          project.should_receive(:latest_build).and_return(latest_build)
          # testing delegation call through mocks
          project.send("latest_build_#{field}")
        end
      end
    end

    context "command" do
      it "does not prefix bundler related command if Gemfile is missing" do
        project = Factory(:project)
        File.should_receive(:exists?).with(File.join(project.code_path, 'Gemfile')).and_return(false)
        project.command.starts_with?("(bundle check || bundle install)").should be_false
      end

      it "prefixes bundler related command if Gemfile is present" do
        project = Factory(:project)
        File.should_receive(:exists?).with(File.join(project.code_path, 'Gemfile')).and_return(true)
        project.command.starts_with?("(bundle check || bundle install)").should be_true
      end

      it "is able to retrieve the custom command" do
        project = Factory(:project, :custom_command => 'cmake')
        project.command.should == 'cmake'
      end

      it "defaults the custom command to rake" do
        project = Factory(:project, :custom_command => nil)
        project.command.should == 'rake'
      end
    end

    it "sets the build requested flag to true" do
      project = Factory(:project, :name => 'name')
      project.force_build
      project.build_requested.should be_true
    end

    context "when to build" do
      it "builds if there are no existing builds" do
        project = Project.new
        project.build_required?.should be_true
      end

      it "builds even if there are existing builds if it is requested" do
        project = Project.new
        project.builds << Build.new
        project.build_requested = true
        project.build_required?.should be_true
      end
    end

    context "run build" do
      let(:project) { Factory(:project, :name => "goldberg") }

      # all tests in this context are testing mock calls Grrrhhhhh

      context "without changes or requested build" do
        it "does not run the build if there are no updates from repository or build is not required" do
          project.should respond_to(:build_required?)
          project.should_receive(:build_required?).and_return(false)
          project.repository.should_receive(:update).and_return(false)
          lambda { project.run_build }.should_not change(project.builds, :size)
        end
      end

      it "runs the build even if there are no updates but a build is requested" do
        build = Build.new
        project.build_requested = true
        project.repository.should_receive(:update).and_return(false)
        project.builds.should_receive(:create!).with(:number => 1, :previous_build_revision => "").and_return(build)
        build.should respond_to(:run)
        build.should_receive(:run)
        project.run_build
      end

      context "with changes" do
        before(:each) do
          project.repository.should respond_to(:update)
          project.repository.should_receive(:update).and_return(true)
        end

        it "creates a new build for a project with build number set to 1 in case of first build  and run it" do
          build = Build.new
          project.builds.should_receive(:create!).with(:number => 1, :previous_build_revision => "").and_return(build)
          build.should respond_to(:run)
          build.should_receive(:run)
          project.run_build
        end

        it "creates a new build for a project with build number one greater than last build and run it" do
          project.builds << Factory(:build, :number => 5, :revision => "old_sha", :project => project)
          build = Build.new
          project.builds.should_receive(:create!).with(:number => 6, :previous_build_revision => "old_sha").and_return(build)
          build.should respond_to(:run)
          build.should_receive(:run)
          project.run_build
        end
      end
    end

    it "is able to return the latest build" do
      project = Factory(:project, :name => 'name')
      first_build = Factory(:build, :project => project)
      last_build = Factory(:build, :project => project)
      project.latest_build.should == last_build
    end
  end
end
