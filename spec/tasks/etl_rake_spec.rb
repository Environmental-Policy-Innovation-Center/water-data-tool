require "rails_helper"
require "rake"

RSpec.describe "etl rake tasks" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("etl:import")
  end

  before do
    Rake::Task["etl:import"].reenable
    allow($stdout).to receive(:puts)
  end

  let(:importer_double) { instance_double(Etl::Importer, call: []) }

  describe "etl:import" do
    it "calls Etl::Importer with no table filter and force: false by default" do
      expect(Etl::Importer).to receive(:new).with(
        force: false,
        only: nil
      ).and_return(importer_double)

      Rake::Task["etl:import"].invoke
    end

    it "passes only: table when a table argument is given" do
      expect(Etl::Importer).to receive(:new).with(
        hash_including(only: "epa_sabs")
      ).and_return(importer_double)

      Rake::Task["etl:import"].invoke("epa_sabs")
    end

    it "passes force: true when mode is 'force'" do
      expect(Etl::Importer).to receive(:new).with(
        hash_including(force: true)
      ).and_return(importer_double)

      Rake::Task["etl:import"].invoke("epa_sabs", "force")
    end

    it "does not pass force: true for any mode other than 'force'" do
      expect(Etl::Importer).to receive(:new).with(
        hash_including(force: false)
      ).and_return(importer_double)

      Rake::Task["etl:import"].invoke("epa_sabs", "true")
    end
  end
end
