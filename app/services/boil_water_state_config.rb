# frozen_string_literal: true

class BoilWaterStateConfig
  def self.config
    @config ||= HomeHelper::TOOLTIPS.dig("boil_water_notices_states") || {}
  end

  def self.states
    @states ||= config.keys.map { |k| k.to_s.upcase }.freeze
  end

  def self.bwn_state?(stusps)
    return false if stusps.blank?
    states.include?(stusps.to_s.upcase)
  end

  def self.states_json
    @states_json ||= states.to_json
  end
end
