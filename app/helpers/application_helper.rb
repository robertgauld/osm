module ApplicationHelper

  # Interpret a string as markdown
  # @param text the text in markdown format
  # @returns an interpreted html_safe string representation of text
  def markdown(text)
    options = [:hard_wrap, :autolink, :no_intraemphasis]
    RedcarpetCompat.new(text, *options).to_html.html_safe
  end

  # Display either yes or no highlighted in gree or red
  # @param value the boolean value being represented
  # @param positive_value (optional, default true) the value to be considered positive (and displayed in green)
  def yes_no(value, positive_value=true)
    if positive_value == value
      return "<span style=\"color: green;\">#{value ? 'yes' : 'no'}</span>".html_safe
    else
      return "<span style=\"color: red;\">#{value ? 'YES' : 'NO'}</span>".html_safe
    end
  end

end
