##
# Structure for saving steps and rendering HTML for timeline and its steps.
class TimelineInSteps < Array
  attr_reader :steps
  def initialize
    @steps = []
  end

  def step(badge_text, bottom_label = '', highlighted = false)
    @steps << { badge_text: badge_text, bottom_label: bottom_label, highlighted: highlighted }
  end

end