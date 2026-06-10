require "rails_helper"

RSpec.describe HomeHelper, type: :helper do
  describe "#hidden_inputs_for_params" do
    before do
      allow(helper).to receive(:request).and_return(
        instance_double(ActionDispatch::Request,
          query_parameters: {"sort" => "pws_name", "direction" => "asc", "cols" => "pwsid,stusps"})
      )
    end

    it "renders a hidden input for each query param" do
      html = helper.hidden_inputs_for_params
      expect(html).to include('name="sort"')
      expect(html).to include('value="pws_name"')
      expect(html).to include('name="direction"')
    end

    it "excludes specified params" do
      html = helper.hidden_inputs_for_params(except: ["cols"])
      expect(html).not_to include('name="cols"')
      expect(html).to include('name="sort"')
    end

    it "renders array params with [] suffix" do
      allow(helper).to receive(:request).and_return(
        instance_double(ActionDispatch::Request,
          query_parameters: {"filters" => ["a", "b"]})
      )
      html = helper.hidden_inputs_for_params
      expect(html).to include('name="filters[]"')
      expect(html).to include('value="a"')
      expect(html).to include('value="b"')
    end
  end

  describe "#cell_value" do
    let(:pws) { create(:public_water_system, pwsid: "TX1234567", pws_name: "Test Water") }

    it "reads directly from pws when source is :pws" do
      col = TableColumn.new(key: :pwsid, label: "Utility ID", sort: nil,
        format: :str, format_opts: {}, size: :default, row_header: false, pinned: false, source: :pws,
        csv_label: nil, sql_expr: nil, category: nil)
      expect(helper.cell_value(pws, col)).to eq("TX1234567")
    end

    it "reads from a preloaded association" do
      create(:demographic, pwsid: pws.pwsid, total_population: 5_000)
      pws_loaded = PublicWaterSystem.includes(:demographic).find(pws.id)
      col = TableColumn.new(key: :total_population, label: "Population", sort: nil,
        format: :num, format_opts: {}, size: :default, row_header: false, pinned: false, source: :demographic,
        csv_label: nil, sql_expr: nil, category: nil)
      expect(helper.cell_value(pws_loaded, col)).to eq(5_000)
    end

    it "returns nil when source is nil (check/link columns)" do
      col = TableColumn.new(key: :check, label: nil, sort: nil,
        format: :check, format_opts: {}, size: :check, row_header: false, pinned: false, source: nil,
        csv_label: nil, sql_expr: nil, category: nil)
      expect(helper.cell_value(pws, col)).to be_nil
    end

    it "returns nil when the associated record does not exist" do
      col = TableColumn.new(key: :total_population, label: "Population", sort: nil,
        format: :num, format_opts: {}, size: :default, row_header: false, pinned: false, source: :demographic,
        csv_label: nil, sql_expr: nil, category: nil)
      expect(helper.cell_value(pws, col)).to be_nil
    end
  end

  describe "#format_cell_value" do
    it "formats :str via fmt_str" do
      expect(helper.format_cell_value("hello", :str, {})).to eq("hello")
      expect(helper.format_cell_value(nil, :str, {})).to eq("—")
    end

    it "formats :bool via fmt_bool" do
      expect(helper.format_cell_value(true, :bool, {})).to eq("Yes")
      expect(helper.format_cell_value(false, :bool, {})).to eq("No")
      expect(helper.format_cell_value(nil, :bool, {})).to eq("—")
    end

    it "formats :num via fmt_num" do
      expect(helper.format_cell_value(1_234, :num, {})).to eq("1,234")
      expect(helper.format_cell_value(nil, :num, {})).to eq("—")
    end

    it "formats :dec via fmt_dec" do
      expect(helper.format_cell_value(3.14159, :dec, {})).to eq("3.14")
      expect(helper.format_cell_value(3.14159, :dec, {precision: 0})).to eq("3")
    end

    it "formats :pct via fmt_pct" do
      expect(helper.format_cell_value(25.5, :pct, {})).to include("25.50")
    end

    it "formats :cur via fmt_cur" do
      expect(helper.format_cell_value(1_000, :cur, {})).to include("1,000")
    end

    it "falls through to fmt_str for unknown formats" do
      expect(helper.format_cell_value("val", :unknown, {})).to eq("val")
    end
  end

  describe "#render_table_cell" do
    let(:pws) { create(:public_water_system, pwsid: "TX0000001", pws_name: "Aloha Water") }

    context "with :check format" do
      let(:col) { ColumnRegistry.columns.find { |c| c.format == :check } }

      it "renders a sticky td with a checkbox input" do
        html = helper.render_table_cell(col, pws, row_stripe: "bg-white")
        expect(html).to include("<td")
        expect(html).to include('type="checkbox"')
        expect(html).to include(pws.pwsid)
      end
    end

    context "with :link format" do
      let(:col) { ColumnRegistry.columns.find { |c| c.format == :link } }

      it "renders an empty td when no URL is present" do
        pws.detailed_facility_report = nil
        html = helper.render_table_cell(col, pws, row_stripe: "bg-white")
        expect(html).to include("<td")
        expect(html).not_to include("<a")
      end

      it "renders a link when a URL is present" do
        pws.detailed_facility_report = "https://example.com/report"
        html = helper.render_table_cell(col, pws, row_stripe: "bg-white")
        expect(html).to include("https://example.com/report")
        expect(html).to include("<a")
      end
    end

    context "with row_header: true column (pws_name)" do
      let(:col) { ColumnRegistry.columns.find(&:row_header) }

      it "renders a <th scope='row'> element" do
        html = helper.render_table_cell(col, pws, row_stripe: "bg-white")
        expect(html).to include("<th")
        expect(html).to include('scope="row"')
        expect(html).to include("Aloha Water")
      end
    end

    context "with :copy format column (pwsid)" do
      let(:col) { ColumnRegistry.columns.find { |c| c.format == :copy } }

      it "renders a td containing the value and a clipboard button" do
        html = helper.render_table_cell(col, pws, row_stripe: "bg-white")
        expect(html).to include("<td")
        expect(html).to include(pws.pwsid)
        expect(html).to include("title=\"Copy #{col.label}\"")
        expect(html).to include('data-controller="clipboard"')
        expect(html).to include('data-clipboard-target="copy"')
        expect(html).to include('data-clipboard-target="check"')
      end
    end

    context "with a numeric column" do
      let(:col) { ColumnRegistry.columns.find { |c| c.key == :total_population } }
      let(:pws_with_demo) do
        create(:demographic, pwsid: pws.pwsid, total_population: 12_345)
        PublicWaterSystem.includes(:demographic).find(pws.id)
      end

      it "renders a td with tabular-nums and text-right" do
        html = helper.render_table_cell(col, pws_with_demo, row_stripe: "bg-white")
        expect(html).to include("tabular-nums")
        expect(html).to include("text-right")
        expect(html).to include("12,345")
      end
    end
  end
end
