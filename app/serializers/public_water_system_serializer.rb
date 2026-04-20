class PublicWaterSystemSerializer
  def initialize(pws)
    @pws = pws
  end

  def serialize
    {
      pwsid: @pws.pwsid,
      pws_name: @pws.pws_name,
      stusps: @pws.stusps,
      primacy_agency: @pws.primacy_agency,
      pop_cat_5: @pws.pop_cat_5,
      population_served_count: @pws.population_served_count,
      service_connections_count: @pws.service_connections_count,
      gw_sw_code: @pws.gw_sw_code,
      owner_type: @pws.owner_type,
      primacy_type: @pws.primacy_type,
      service_area_type: @pws.service_area_type,
      area_sq_miles: @pws.area_sq_miles,
      open_health_viol: @pws.open_health_viol,
      is_wholesaler: @pws.is_wholesaler,
      is_school_or_daycare: @pws.is_school_or_daycare,
      counties: @pws.counties
    }
  end
end
