module PublicWaterSystems
  class HistogramsController < ApplicationController
    FIELD_CONFIG = {
      **Filterable::PAPERWORK_VIOLATIONS_COLS.index_with { {model: ViolationsSummary} },
      **Filterable::HEALTH_SUBCATS_ALL.index_with { {model: ViolationsSummary} },

      # TODO - wrap these into Filterable lists like above
      poverty_rate: {model: Demographic},
      unemployment_rate: {model: Demographic},
      median_household_income: {model: Demographic},
      bachelors_degree_rate: {model: Demographic},
      age_under_5_rate: {model: Demographic},
      age_over_61_rate: {model: Demographic},
      poc_rate: {model: Demographic},
      white_rate: {model: Demographic},
      black_rate: {model: Demographic},
      aian_rate: {model: Demographic},
      napi_rate: {model: Demographic},
      asian_rate: {model: Demographic},
      hispanic_rate: {model: Demographic},
      other_race_rate: {model: Demographic},
      mixed_race_rate: {model: Demographic},

      cejst_disadvantaged_pct: {model: EnvironmentalJustice},
      svi_overall_pctl: {model: EnvironmentalJustice},
      cvi_overall_score: {model: EnvironmentalJustice},

      population_pct_change_capped: {model: TrendDatum, min_threshold: nil},
      mhi_pct_change_capped: {model: TrendDatum, min_threshold: nil},

      num_facilities: {model: WatershedHazard},
      permit_effluent_violations: {model: WatershedHazard},
      open_underground_storage_tanks: {model: WatershedHazard},
      risk_management_plan_facilities: {model: WatershedHazard},
      impaired_streams_303d: {model: WatershedHazard},

      times_funded: {model: FundingSummary},
      total_srf_assistance: {model: FundingSummary},
      total_principal_forgiveness: {model: FundingSummary}
    }.freeze

    # TODO - is this even being used?
    ALLOWED_FIELDS = FIELD_CONFIG.keys.map(&:to_s).freeze

    def show
      field = params[:field]
      config = FIELD_CONFIG[field&.to_sym]
      return render json: {error: "Unknown field"}, status: :bad_request unless config

      model = config[:model]
      kwargs = config.except(:model)
      render json: model.histogram_bins(field, **kwargs)
    end
  end
end
